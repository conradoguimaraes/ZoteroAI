import Foundation

enum CandidateCombiner {
    static func combine(
        pdf: [MetadataCandidate],
        online: [MetadataCandidate],
        item: ItemSnapshot
    ) -> [MetadataCandidate] {
        let all = (pdf + online).filter {
            shouldProposeCandidate(field: $0.field, candidateValue: $0.value, item: item)
        }

        var groups: [String: [MetadataCandidate]] = [:]
        for candidate in all {
            let key = "\(candidate.field)|\(candidate.value.zmeNormalized)"
            groups[key, default: []].append(candidate)
        }

        var merged: [MetadataCandidate] = []
        for group in groups.values {
            guard let first = group.first else { continue }
            if group.count == 1 {
                merged.append(first)
                continue
            }

            let sources = uniquePreservingOrder(group.map(\.source))
            let evidence = uniquePreservingOrder(
                group.compactMap(\.evidence).map(\.zmeCollapsedWhitespace).filter { !$0.isEmpty }
            )

            let hasPDF = group.contains { candidate in
                candidate.status == .pdfExtracted || candidate.status == .aiFromPDF || candidate.source.localizedCaseInsensitiveContains("PDF")
            }
            let hasOnline = group.contains { candidate in
                candidate.status == .verified || candidate.status == .online || candidate.source.contains("Crossref") || candidate.source.contains("DataCite") || candidate.source.contains("OpenAlex")
            }

            let strongestStatus: CandidateStatus
            if hasPDF && hasOnline {
                strongestStatus = .corroborated
            } else if group.contains(where: { $0.status == .corroborated }) {
                strongestStatus = .corroborated
            } else if group.contains(where: { $0.status == .verified }) {
                strongestStatus = .verified
            } else if group.contains(where: { $0.status == .pdfExtracted }) {
                strongestStatus = .pdfExtracted
            } else if group.contains(where: { $0.status == .aiFromPDF }) {
                strongestStatus = .aiFromPDF
            } else {
                strongestStatus = .online
            }

            let bestStructuredValue = group
                .sorted { $0.confidence > $1.confidence }
                .compactMap(\.structuredValue)
                .first

            merged.append(
                MetadataCandidate(
                    id: candidateID(),
                    field: first.field,
                    value: first.value,
                    structuredValue: bestStructuredValue,
                    source: sources.joined(separator: " + "),
                    status: strongestStatus,
                    evidence: evidence.isEmpty ? nil : evidence.joined(separator: " · "),
                    confidence: min(0.99, (group.map(\.confidence).max() ?? first.confidence) + (hasPDF && hasOnline ? 0.05 : 0.0))
                )
            )
        }

        let preferredOrder = [
            "title", "creators", "DOI", "publicationTitle", "conferenceName",
            "proceedingsTitle", "date", "volume", "issue", "pages", "publisher",
            "place", "ISSN", "ISBN", "url", "language", "abstractNote", "tags"
        ]
        let order = Dictionary(uniqueKeysWithValues: preferredOrder.enumerated().map { ($1, $0) })

        return merged.sorted {
            let lhsOrder = order[$0.field] ?? 999
            let rhsOrder = order[$1.field] ?? 999
            if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
            if $0.field != $1.field { return $0.field < $1.field }
            if $0.confidence != $1.confidence { return $0.confidence > $1.confidence }
            return $0.value.localizedCaseInsensitiveCompare($1.value) == .orderedAscending
        }
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for value in values where !value.isEmpty {
            if seen.insert(value).inserted {
                output.append(value)
            }
        }
        return output
    }
}
