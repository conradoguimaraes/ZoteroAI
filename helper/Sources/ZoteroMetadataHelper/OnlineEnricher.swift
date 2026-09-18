#if os(macOS)
import Foundation

enum OnlineEnricher {
    static func enrich(item: ItemSnapshot) async -> EnrichmentResponse {
        let records = await ScholarlySources().lookupAll(item: item)
        var notes: [String] = []

        if records.isEmpty {
            return EnrichmentResponse(
                requestID: "",
                candidates: [],
                notes: ["No sufficiently strong record match was found in Crossref, DataCite, or OpenAlex."]
            )
        }

        let candidates = merge(records: records, item: item)
        notes.append("Online stage queried structured scholarly metadata sources. Generic Siri web search is not used because Apple does not expose the Ask Siri web-search pipeline as a public app API.")
        notes.append("A title-search result is discarded unless its normalized title similarity is at least 0.72. DOI-resolved records are also rejected when an existing item title is clearly inconsistent (similarity below 0.55), after which that provider falls back to title search.")

        return EnrichmentResponse(requestID: "", candidates: candidates, notes: notes)
    }

    private static func merge(records: [SourceRecord], item: ItemSnapshot) -> [MetadataCandidate] {
        var valueGroups: [String: [(field: String, value: String, source: SourceRecord)]] = [:]

        for record in records {
            for (field, value) in record.fields where !value.zmeTrimmed.isEmpty {
                let key = "\(field)|\(value.zmeNormalized)"
                valueGroups[key, default: []].append((field, value, record))
            }

            if !record.creators.isEmpty {
                let display = record.creators.map { [$0.firstName, $0.lastName].filter { !$0.isEmpty }.joined(separator: " ") }.joined(separator: "; ")
                let key = "creators|\(display.zmeNormalized)"
                valueGroups[key, default: []].append(("creators", display, record))
            }

            if !record.tags.isEmpty {
                let display = record.tags.joined(separator: "; ")
                let key = "tags|\(display.zmeNormalized)"
                valueGroups[key, default: []].append(("tags", display, record))
            }
        }

        var perField: [String: [(String, [(field: String, value: String, source: SourceRecord)])]] = [:]
        for (key, entries) in valueGroups {
            guard let field = entries.first?.field else { continue }
            perField[field, default: []].append((key, entries))
        }

        var output: [MetadataCandidate] = []
        for (field, groups) in perField {
            let sorted = groups.sorted { lhs, rhs in
                score(lhs.1) > score(rhs.1)
            }
            guard let winner = sorted.first, let first = winner.1.first else { continue }
            let value = first.value
            guard shouldProposeCandidate(field: field, candidateValue: value, item: item) else { continue }

            let sources = Array(Set(winner.1.map { $0.source.source })).sorted()
            let exactIdentifier = winner.1.contains { $0.source.identifierMatch }
            let corroborated = sources.count >= 2
            let status: CandidateStatus = corroborated ? .corroborated : (exactIdentifier ? .verified : .online)
            let confidence = min(0.99, max(0.55, score(winner.1)))

            var structured: String? = nil
            if field == "creators" {
                if let source = winner.1.map({ $0.source }).first(where: { !$0.creators.isEmpty }) {
                    structured = encodedJSONString(source.creators)
                }
            } else if field == "tags" {
                if let source = winner.1.map({ $0.source }).first(where: { !$0.tags.isEmpty }) {
                    structured = encodedJSONString(source.tags)
                }
            }

            let evidence = exactIdentifier
                ? "Matched using the item's DOI."
                : "Matched by title; best normalized title similarity: \(String(format: "%.2f", winner.1.map { $0.source.titleSimilarity }.max() ?? 0))."

            output.append(
                MetadataCandidate(
                    id: candidateID(),
                    field: field,
                    value: value,
                    structuredValue: structured,
                    source: sources.joined(separator: " + "),
                    status: status,
                    evidence: evidence,
                    confidence: confidence
                )
            )
        }

        let preferredOrder = [
            "title", "creators", "DOI", "publicationTitle", "conferenceName",
            "proceedingsTitle", "date", "volume", "issue", "pages", "publisher",
            "place", "ISSN", "ISBN", "url", "language", "abstractNote", "tags"
        ]
        let order = Dictionary(uniqueKeysWithValues: preferredOrder.enumerated().map { ($1, $0) })
        return output.sorted {
            (order[$0.field] ?? 999, $0.field) < (order[$1.field] ?? 999, $1.field)
        }
    }

    private static func score(_ entries: [(field: String, value: String, source: SourceRecord)]) -> Double {
        let sourceCount = Double(Set(entries.map { $0.source.source }).count)
        let exact = entries.contains { $0.source.identifierMatch }
        let similarity = entries.map { $0.source.titleSimilarity }.max() ?? 0
        var result = 0.45 + similarity * 0.35
        if exact { result += 0.15 }
        if sourceCount >= 2 { result += 0.15 }
        return min(result, 0.99)
    }
}
#endif
