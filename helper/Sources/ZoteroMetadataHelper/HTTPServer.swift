#if os(macOS)
import Foundation
import Network

final class LocalHTTPServer {
    private let port: NWEndpoint.Port = 43119
    private let token: String
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "zme.http.server", qos: .userInitiated)

    init(token: String) {
        self.token = token
    }

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: port)

        // Do not also pass `on: port` here. Network.framework treats an
        // explicit listener port together with a `requiredLocalEndpoint`
        // containing its own port as incompatible and NWListener throws
        // POSIX EINVAL (NWError error 22). The required endpoint already
        // pins this listener to 127.0.0.1:43119.
        let listener = try NWListener(using: parameters)
        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Zotero Metadata Helper listening on 127.0.0.1:\(self.port)")
            case .failed(let error):
                FileHandle.standardError.write(Data("Helper listener failed: \(error)\n".utf8))
            default:
                break
            }
        }
        listener.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        var buffer = Data()

        func receiveMore() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, isComplete, error in
                guard let self else { return }
                if let data { buffer.append(data) }
                if buffer.count > 2_000_000 {
                    self.send(.json(status: 413, object: ErrorResponse(error: "Request body is too large.")), over: connection)
                    return
                }
                if error != nil {
                    connection.cancel()
                    return
                }

                if let request = HTTPRequestParser.parseIfComplete(buffer) {
                    Task {
                        let response = await self.route(request)
                        self.send(response, over: connection)
                    }
                    return
                }

                if isComplete {
                    self.send(.json(status: 400, object: ErrorResponse(error: "Malformed HTTP request.")), over: connection)
                } else {
                    receiveMore()
                }
            }
        }

        receiveMore()
    }

    private func route(_ request: HTTPRequest) async -> HTTPResponse {
        if request.method == "GET" && request.path == "/health" {
            return .json(
                status: 200,
                object: HealthResponse(
                    service: "Zotero Metadata Helper",
                    version: BuildInfo.version,
                    build: BuildInfo.build,
                    appleIntelligenceAvailable: AppleIntelligenceAnalyzer.isAvailable
                )
            )
        }

        guard request.headers["x-zme-token"] == token else {
            return .json(status: 401, object: ErrorResponse(error: "Unauthorized helper request."))
        }

        guard request.method == "POST" else {
            return .json(status: 405, object: ErrorResponse(error: "Method not allowed."))
        }

        let decoder = JSONDecoder()
        guard let payload = try? decoder.decode(EnrichmentRequest.self, from: request.body) else {
            return .json(status: 400, object: ErrorResponse(error: "Invalid JSON request payload."))
        }

        switch request.path {
        case "/v1/pdf-enrich":
            do {
                let response = try await pdfEnrichment(payload: payload, offlineOnly: true)
                return .json(status: 200, object: response)
            } catch {
                return .json(status: 422, object: ErrorResponse(error: error.localizedDescription))
            }

        case "/v1/online-enrich":
            var response = await OnlineEnricher.enrich(item: payload.item)
            response.requestID = payload.requestID
            return .json(status: 200, object: response)

        case "/v1/combined-enrich":
            do {
                let pdfResponse = try await pdfEnrichment(payload: payload, offlineOnly: false)
                var onlineResponse = await OnlineEnricher.enrich(item: payload.item)
                onlineResponse.requestID = payload.requestID

                let candidates = CandidateCombiner.combine(
                    pdf: pdfResponse.candidates,
                    online: onlineResponse.candidates,
                    item: payload.item
                )
                let notes = [
                    "Combined enrichment used the stored PDF and structured online scholarly sources.",
                    "When the PDF and an online source agree on the same value, that value is marked as corroborated.",
                    "Conflicting alternatives remain separate proposals and are never applied automatically."
                ] + pdfResponse.notes + onlineResponse.notes

                return .json(
                    status: 200,
                    object: EnrichmentResponse(requestID: payload.requestID, candidates: candidates, notes: notes)
                )
            } catch {
                return .json(status: 422, object: ErrorResponse(error: error.localizedDescription))
            }

        default:
            return .json(status: 404, object: ErrorResponse(error: "Unknown helper endpoint."))
        }
    }

    private func pdfEnrichment(payload: EnrichmentRequest, offlineOnly: Bool) async throws -> EnrichmentResponse {
        guard let pdfPath = payload.pdfPath, !pdfPath.isEmpty else {
            throw NSError(
                domain: "ZME.PDF",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "A stored PDF path is required for PDF-based enrichment."]
            )
        }

        guard FileManager.default.fileExists(atPath: pdfPath) else {
            throw NSError(
                domain: "ZME.PDF",
                code: 11,
                userInfo: [NSLocalizedDescriptionKey: "The stored PDF file no longer exists at the path provided by Zotero."]
            )
        }
        guard FileManager.default.isReadableFile(atPath: pdfPath) else {
            throw NSError(
                domain: "ZME.PDF",
                code: 12,
                userInfo: [NSLocalizedDescriptionKey: "The stored PDF exists, but the Metadata Helper cannot read it. Check macOS file permissions for Zotero Metadata Helper."]
            )
        }

        let extraction = try PDFTextExtractor.extract(from: pdfPath)
        var candidates = extraction.deterministicCandidates.filter {
            shouldProposeCandidate(field: $0.field, candidateValue: $0.value, item: payload.item)
        }
        var notes = ["PDF text extracted from \(extraction.pageCount) page(s)."]
        if offlineOnly {
            notes.append("No network lookup was performed in this stage.")
        }

        do {
            let ai = try await AppleIntelligenceAnalyzer.analyzePDF(excerpt: extraction.excerpt, item: payload.item)
            candidates.append(contentsOf: ai)
        } catch {
            notes.append("Apple Intelligence analysis was unavailable or failed: \(error.localizedDescription)")
        }

        candidates = deduplicateCandidates(candidates)
        return EnrichmentResponse(requestID: payload.requestID, candidates: candidates, notes: notes)
    }

    private func send(_ response: HTTPResponse, over connection: NWConnection) {
        var header = "HTTP/1.1 \(response.status) \(HTTPResponse.reasonPhrase(for: response.status))\r\n"
        header += "Content-Type: application/json; charset=utf-8\r\n"
        header += "Content-Length: \(response.body.count)\r\n"
        header += "Connection: close\r\n"
        header += "Cache-Control: no-store\r\n\r\n"

        var data = Data(header.utf8)
        data.append(response.body)
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func deduplicateCandidates(_ input: [MetadataCandidate]) -> [MetadataCandidate] {
        var byKey: [String: MetadataCandidate] = [:]
        for candidate in input {
            let key = "\(candidate.field)|\(candidate.value.zmeNormalized)"
            if let existing = byKey[key] {
                if candidate.confidence > existing.confidence {
                    byKey[key] = candidate
                }
            } else {
                byKey[key] = candidate
            }
        }
        return Array(byKey.values).sorted { $0.field < $1.field }
    }
}

struct HTTPRequest {
    var method: String
    var path: String
    var headers: [String: String]
    var body: Data
}

struct HTTPResponse {
    var status: Int
    var body: Data

    static func json<T: Encodable>(status: Int, object: T) -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(object)) ?? Data("{\"error\":\"Encoding failure\"}".utf8)
        return HTTPResponse(status: status, body: data)
    }

    static func reasonPhrase(for status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 413: return "Payload Too Large"
        case 422: return "Unprocessable Entity"
        default: return "Response"
        }
    }
}

enum HTTPRequestParser {
    static func parseIfComplete(_ data: Data) -> HTTPRequest? {
        let marker = Data("\r\n\r\n".utf8)
        guard let headerRange = data.range(of: marker) else { return nil }
        let headerData = data[..<headerRange.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).zmeTrimmed.lowercased()
            let value = String(line[line.index(after: colon)...]).zmeTrimmed
            headers[key] = value
        }

        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        let bodyStart = headerRange.upperBound
        let availableBody = data.count - bodyStart
        guard availableBody >= contentLength else { return nil }
        let body = data.subdata(in: bodyStart..<(bodyStart + contentLength))

        return HTTPRequest(
            method: String(parts[0]).uppercased(),
            path: String(parts[1]).components(separatedBy: "?").first ?? String(parts[1]),
            headers: headers,
            body: body
        )
    }
}
#endif
