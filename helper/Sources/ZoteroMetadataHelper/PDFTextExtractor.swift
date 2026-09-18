#if os(macOS)
import Foundation
import PDFKit

struct PDFExtractionResult {
    var pageCount: Int
    var text: String
    var excerpt: String
    var deterministicCandidates: [MetadataCandidate]
}

enum PDFTextExtractor {
    static func extract(from path: String) throws -> PDFExtractionResult {
        let url = URL(fileURLWithPath: path)
        guard let document = PDFDocument(url: url) else {
            throw NSError(domain: "ZME.PDF", code: 1, userInfo: [NSLocalizedDescriptionKey: "The PDF could not be opened."])
        }

        var pages: [String] = []
        pages.reserveCapacity(document.pageCount)
        for index in 0..<document.pageCount {
            let text = document.page(at: index)?.string?.zmeTrimmed ?? ""
            pages.append(text)
        }

        let allText = pages.joined(separator: "\n\n")
        if allText.zmeTrimmed.count < 80 {
            throw NSError(
                domain: "ZME.PDF",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "The PDF contains too little extractable text. Scanned-image OCR is not implemented yet."]
            )
        }

        let excerpt = buildExcerpt(pages: pages)
        let deterministic = deterministicMetadata(from: allText)

        return PDFExtractionResult(
            pageCount: document.pageCount,
            text: allText,
            excerpt: excerpt,
            deterministicCandidates: deterministic
        )
    }

    private static func buildExcerpt(pages: [String]) -> String {
        // Apple documents a 4,096-token context window for the on-device model.
        // Metadata is normally concentrated at the beginning of a paper, so keep
        // this excerpt deliberately small enough to leave room for instructions,
        // the generated schema, and the response.
        let maxCharacters = 8_500
        var selected: [(Int, String)] = []
        var total = 0

        let frontCount = min(pages.count, 12)
        for index in 0..<frontCount {
            let text = pages[index]
            if text.isEmpty { continue }
            let remaining = maxCharacters - total
            if remaining <= 0 { break }
            let clipped = String(text.prefix(remaining))
            selected.append((index, clipped))
            total += clipped.count
            if clipped.count < text.count { break }
        }

        if pages.count > frontCount {
            for index in max(frontCount, pages.count - 2)..<pages.count {
                let text = pages[index]
                if text.isEmpty { continue }
                if selected.contains(where: { $0.0 == index }) { continue }
                let remaining = maxCharacters - total
                if remaining <= 0 { break }
                let clipped = String(text.prefix(remaining))
                selected.append((index, clipped))
                total += clipped.count
            }
        }

        return selected
            .sorted(by: { $0.0 < $1.0 })
            .map { "--- PAGE \($0.0 + 1) ---\n\($0.1)" }
            .joined(separator: "\n\n")
    }

    private static func deterministicMetadata(from text: String) -> [MetadataCandidate] {
        var candidates: [MetadataCandidate] = []

        if let doi = firstMatch(
            pattern: #"(?i)\b10\.\d{4,9}/[-._;()/:A-Z0-9]+\b"#,
            in: text
        )?.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:)\"]}")) {
            candidates.append(
                MetadataCandidate(
                    id: candidateID(),
                    field: "DOI",
                    value: doi,
                    structuredValue: nil,
                    source: "Stored PDF (DOI pattern)",
                    status: .pdfExtracted,
                    evidence: doi,
                    confidence: 0.99
                )
            )
        }

        return candidates
    }

    private static func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let swiftRange = Range(match.range, in: text) else {
            return nil
        }
        return String(text[swiftRange])
    }
}
#endif
