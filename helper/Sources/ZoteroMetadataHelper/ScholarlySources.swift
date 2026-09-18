#if os(macOS)
import Foundation

struct ScholarlySources {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    func lookupAll(item: ItemSnapshot) async -> [SourceRecord] {
        async let crossref = lookupCrossref(item: item)
        async let datacite = lookupDataCite(item: item)
        async let openAlex = lookupOpenAlex(item: item)

        let results = await [crossref, datacite, openAlex]
        return results.compactMap { $0 }
    }

    private func lookupCrossref(item: ItemSnapshot) async -> SourceRecord? {
        let doi = normalizedDOI(item.fields["DOI"])
        let title = item.fields["title"]?.zmeTrimmed ?? ""

        var url: URL?
        var identifierMatch = false

        if let doi, !doi.isEmpty {
            let escaped = doi.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? doi
            url = URL(string: "https://api.crossref.org/works/\(escaped)")
            identifierMatch = true
        } else if !title.isEmpty {
            var components = URLComponents(string: "https://api.crossref.org/works")!
            components.queryItems = [
                URLQueryItem(name: "query.bibliographic", value: title),
                URLQueryItem(name: "rows", value: "3")
            ]
            url = components.url
        }

        guard let url else { return nil }
        guard let json = await fetchJSON(url: url) else {
            return identifierMatch ? await lookupCrossref(item: itemWithoutDOI(item)) : nil
        }
        let records: [[String: Any]]

        if identifierMatch,
           let message = json["message"] as? [String: Any] {
            records = [message]
        } else if let message = json["message"] as? [String: Any],
                  let items = message["items"] as? [[String: Any]] {
            records = items
        } else {
            return nil
        }

        guard let best = bestRecord(records, targetTitle: title, titleExtractor: { firstString($0["title"]) }) else {
            return identifierMatch ? await lookupCrossref(item: itemWithoutDOI(item)) : nil
        }
        let record = best.record
        let recordTitle = firstString(record["title"]) ?? ""
        let similarity = title.isEmpty ? 1.0 : jaccardTitleSimilarity(title, recordTitle)
        if !identifierMatch && similarity < 0.72 { return nil }
        // An existing DOI is only useful if it still describes this Zotero item.
        // Reject a resolved DOI record whose title is clearly inconsistent with the
        // current item instead of treating a possibly-wrong DOI as authoritative.
        if identifierMatch && !title.isEmpty && !recordTitle.isEmpty && similarity < 0.55 {
            return await lookupCrossref(item: itemWithoutDOI(item))
        }

        var fields: [String: String] = [:]
        assign(&fields, "title", recordTitle)
        assign(&fields, "DOI", record["DOI"] as? String)
        assign(&fields, containerTitleField(for: item.itemType), firstString(record["container-title"]))
        assign(&fields, "publisher", record["publisher"] as? String)
        assign(&fields, "volume", record["volume"] as? String)
        assign(&fields, "issue", record["issue"] as? String)
        assign(&fields, "pages", record["page"] as? String)
        assign(&fields, "url", record["URL"] as? String)
        assign(&fields, "ISSN", firstString(record["ISSN"]))
        assign(&fields, "abstractNote", stripTags(record["abstract"] as? String))
        assign(&fields, "date", crossrefDate(record))

        let creators = ((record["author"] as? [[String: Any]]) ?? []).compactMap { author -> CreatorSnapshot? in
            let family = (author["family"] as? String)?.zmeCollapsedWhitespace ?? ""
            let given = (author["given"] as? String)?.zmeCollapsedWhitespace ?? ""
            if family.isEmpty && given.isEmpty { return nil }
            return CreatorSnapshot(firstName: given, lastName: family, creatorType: "author")
        }

        return SourceRecord(
            source: "Crossref",
            identifierMatch: identifierMatch,
            titleSimilarity: similarity,
            fields: fields,
            creators: creators,
            tags: []
        )
    }

    private func lookupDataCite(item: ItemSnapshot) async -> SourceRecord? {
        let doi = normalizedDOI(item.fields["DOI"])
        let title = item.fields["title"]?.zmeTrimmed ?? ""

        var url: URL?
        var identifierMatch = false

        if let doi, !doi.isEmpty {
            let escaped = doi.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? doi
            url = URL(string: "https://api.datacite.org/dois/\(escaped)")
            identifierMatch = true
        } else if !title.isEmpty {
            var components = URLComponents(string: "https://api.datacite.org/dois")!
            components.queryItems = [
                URLQueryItem(name: "query", value: title),
                URLQueryItem(name: "page[size]", value: "3"),
                URLQueryItem(name: "disable-facets", value: "true")
            ]
            url = components.url
        }

        guard let url else { return nil }
        guard let json = await fetchJSON(url: url) else {
            return identifierMatch ? await lookupDataCite(item: itemWithoutDOI(item)) : nil
        }
        let dataRecords: [[String: Any]]
        if identifierMatch,
           let data = json["data"] as? [String: Any] {
            dataRecords = [data]
        } else {
            dataRecords = json["data"] as? [[String: Any]] ?? []
        }

        let records = dataRecords.compactMap { $0["attributes"] as? [String: Any] }
        guard let best = bestRecord(records, targetTitle: title, titleExtractor: { dataCiteTitle($0) }) else {
            return identifierMatch ? await lookupDataCite(item: itemWithoutDOI(item)) : nil
        }
        let record = best.record
        let recordTitle = dataCiteTitle(record) ?? ""
        let similarity = title.isEmpty ? 1.0 : jaccardTitleSimilarity(title, recordTitle)
        if !identifierMatch && similarity < 0.72 { return nil }
        // An existing DOI is only useful if it still describes this Zotero item.
        // Reject a resolved DOI record whose title is clearly inconsistent with the
        // current item instead of treating a possibly-wrong DOI as authoritative.
        if identifierMatch && !title.isEmpty && !recordTitle.isEmpty && similarity < 0.55 {
            return await lookupDataCite(item: itemWithoutDOI(item))
        }

        var fields: [String: String] = [:]
        assign(&fields, "title", recordTitle)
        assign(&fields, "DOI", record["doi"] as? String)
        assign(&fields, "publisher", dataCitePublisher(record))
        if let year = record["publicationYear"] as? Int {
            assign(&fields, "date", String(year))
        }
        assign(&fields, "url", record["url"] as? String)
        assign(&fields, "language", record["language"] as? String)

        let creators = ((record["creators"] as? [[String: Any]]) ?? []).compactMap { creator -> CreatorSnapshot? in
            let family = (creator["familyName"] as? String)?.zmeCollapsedWhitespace ?? ""
            let given = (creator["givenName"] as? String)?.zmeCollapsedWhitespace ?? ""
            // Do not split an undivided display name heuristically. A wrong family-name
            // boundary silently damages citations. Crossref or PDF review can provide a
            // structured author list when DataCite does not.
            guard !family.isEmpty || !given.isEmpty else { return nil }
            return CreatorSnapshot(firstName: given, lastName: family, creatorType: "author")
        }

        let tags = ((record["subjects"] as? [[String: Any]]) ?? [])
            .compactMap { ($0["subject"] as? String)?.zmeCollapsedWhitespace }
            .filter { !$0.isEmpty }

        return SourceRecord(
            source: "DataCite",
            identifierMatch: identifierMatch,
            titleSimilarity: similarity,
            fields: fields,
            creators: creators,
            tags: tags
        )
    }

    private func lookupOpenAlex(item: ItemSnapshot) async -> SourceRecord? {
        let doi = normalizedDOI(item.fields["DOI"])
        let title = item.fields["title"]?.zmeTrimmed ?? ""

        var url: URL?
        var identifierMatch = false

        if let doi, !doi.isEmpty {
            let identifier = "https://doi.org/\(doi)"
            let escaped = identifier.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? identifier
            url = URL(string: "https://api.openalex.org/works/\(escaped)")
            identifierMatch = true
        } else if !title.isEmpty {
            var components = URLComponents(string: "https://api.openalex.org/works")!
            components.queryItems = [
                URLQueryItem(name: "search", value: title),
                URLQueryItem(name: "per_page", value: "3")
            ]
            url = components.url
        }

        guard let url else { return nil }
        guard let json = await fetchJSON(url: url) else {
            return identifierMatch ? await lookupOpenAlex(item: itemWithoutDOI(item)) : nil
        }
        let records: [[String: Any]]
        if identifierMatch {
            records = [json]
        } else {
            records = json["results"] as? [[String: Any]] ?? []
        }

        guard let best = bestRecord(records, targetTitle: title, titleExtractor: { $0["title"] as? String }) else {
            return identifierMatch ? await lookupOpenAlex(item: itemWithoutDOI(item)) : nil
        }
        let record = best.record
        let recordTitle = (record["title"] as? String)?.zmeCollapsedWhitespace ?? ""
        let similarity = title.isEmpty ? 1.0 : jaccardTitleSimilarity(title, recordTitle)
        if !identifierMatch && similarity < 0.72 { return nil }
        // An existing DOI is only useful if it still describes this Zotero item.
        // Reject a resolved DOI record whose title is clearly inconsistent with the
        // current item instead of treating a possibly-wrong DOI as authoritative.
        if identifierMatch && !title.isEmpty && !recordTitle.isEmpty && similarity < 0.55 {
            return await lookupOpenAlex(item: itemWithoutDOI(item))
        }

        var fields: [String: String] = [:]
        assign(&fields, "title", recordTitle)
        assign(&fields, "DOI", normalizedDOI(record["doi"] as? String))
        if let year = record["publication_year"] as? Int {
            assign(&fields, "date", String(year))
        }

        if let primary = record["primary_location"] as? [String: Any],
           let source = primary["source"] as? [String: Any] {
            assign(&fields, containerTitleField(for: item.itemType), source["display_name"] as? String)
        }

        if let biblio = record["biblio"] as? [String: Any] {
            assign(&fields, "volume", biblio["volume"] as? String)
            assign(&fields, "issue", biblio["issue"] as? String)
            let first = biblio["first_page"] as? String
            let last = biblio["last_page"] as? String
            if let first, !first.isEmpty {
                assign(&fields, "pages", (last?.isEmpty == false && last != first) ? "\(first)-\(last!)" : first)
            }
        }

        // OpenAlex exposes display names, but this project deliberately avoids
        // guessing given/family-name boundaries from a single display string.
        // Use OpenAlex for bibliographic corroboration, not creator replacement.
        return SourceRecord(
            source: "OpenAlex",
            identifierMatch: identifierMatch,
            titleSimilarity: similarity,
            fields: fields,
            creators: [],
            tags: []
        )
    }

    private func fetchJSON(url: URL) async -> [String: Any]? {
        var request = URLRequest(url: url)
        request.setValue("ZoteroMetadataEnricher/0.1 (personal local app)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            return nil
        }
    }

    private func bestRecord(
        _ records: [[String: Any]],
        targetTitle: String,
        titleExtractor: ([String: Any]) -> String?
    ) -> (record: [String: Any], score: Double)? {
        guard !records.isEmpty else { return nil }
        if targetTitle.isEmpty { return (records[0], 1.0) }

        return records.compactMap { record -> ([String: Any], Double)? in
            guard let title = titleExtractor(record), !title.isEmpty else { return nil }
            return (record, jaccardTitleSimilarity(targetTitle, title))
        }.max(by: { $0.1 < $1.1 })
    }

    private func normalizedDOI(_ raw: String?) -> String? {
        guard var value = raw?.zmeTrimmed, !value.isEmpty else { return nil }
        value = value.replacingOccurrences(of: "https://doi.org/", with: "", options: [.caseInsensitive])
        value = value.replacingOccurrences(of: "http://doi.org/", with: "", options: [.caseInsensitive])
        value = value.replacingOccurrences(of: "doi:", with: "", options: [.caseInsensitive])
        return value.zmeTrimmed
    }


    private func itemWithoutDOI(_ item: ItemSnapshot) -> ItemSnapshot {
        var copy = item
        copy.fields["DOI"] = ""
        return copy
    }

    private func containerTitleField(for itemType: String) -> String {
        switch itemType {
        case "conferencePaper":
            return "proceedingsTitle"
        case "bookSection":
            return "bookTitle"
        case "encyclopediaArticle":
            return "encyclopediaTitle"
        case "dictionaryEntry":
            return "dictionaryTitle"
        default:
            return "publicationTitle"
        }
    }

    private func assign(_ fields: inout [String: String], _ key: String, _ raw: String?) {
        guard let value = raw?.zmeCollapsedWhitespace, !value.isEmpty else { return }
        fields[key] = value
    }

    private func firstString(_ value: Any?) -> String? {
        if let value = value as? String { return value.zmeCollapsedWhitespace }
        if let values = value as? [String] { return values.first?.zmeCollapsedWhitespace }
        return nil
    }

    private func stripTags(_ value: String?) -> String? {
        guard let value else { return nil }
        return value.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression).zmeCollapsedWhitespace
    }

    private func crossrefDate(_ record: [String: Any]) -> String? {
        for key in ["published-print", "published-online", "published", "issued"] {
            if let date = record[key] as? [String: Any],
               let parts = date["date-parts"] as? [[Int]],
               let first = parts.first,
               !first.isEmpty {
                return first.map(String.init).joined(separator: "-")
            }
        }
        return nil
    }

    private func dataCiteTitle(_ record: [String: Any]) -> String? {
        if let titles = record["titles"] as? [[String: Any]] {
            return (titles.first?["title"] as? String)?.zmeCollapsedWhitespace
        }
        return nil
    }

    private func dataCitePublisher(_ record: [String: Any]) -> String? {
        if let publisher = record["publisher"] as? String { return publisher.zmeCollapsedWhitespace }
        if let publisher = record["publisher"] as? [String: Any] {
            return (publisher["name"] as? String)?.zmeCollapsedWhitespace
        }
        return nil
    }
}
#endif
