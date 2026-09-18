import Foundation

struct CreatorSnapshot: Codable, Hashable {
    var firstName: String
    var lastName: String
    var creatorType: String
}

struct ItemSnapshot: Codable {
    var itemID: Int
    var itemKey: String
    var libraryID: Int
    var itemType: String
    var fields: [String: String]
    var creators: [CreatorSnapshot]
    var tags: [String]
}

struct EnrichmentRequest: Codable {
    var requestID: String
    var item: ItemSnapshot
    var pdfPath: String?
}

enum CandidateStatus: String, Codable {
    case verified
    case corroborated
    case pdfExtracted
    case aiFromPDF
    case online
}

struct MetadataCandidate: Codable, Hashable {
    var id: String
    var field: String
    var value: String
    var structuredValue: String?
    var source: String
    var status: CandidateStatus
    var evidence: String?
    var confidence: Double
}

struct EnrichmentResponse: Codable {
    var requestID: String
    var candidates: [MetadataCandidate]
    var notes: [String]
}

struct ErrorResponse: Codable {
    var error: String
}

struct HealthResponse: Codable {
    var service: String
    var version: String
    var build: Int
    var appleIntelligenceAvailable: Bool
}

struct SourceRecord {
    var source: String
    var identifierMatch: Bool
    var titleSimilarity: Double
    var fields: [String: String]
    var creators: [CreatorSnapshot]
    var tags: [String]
}

extension String {
    var zmeTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var zmeCollapsedWhitespace: String {
        replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .zmeTrimmed
    }

    var zmeNormalized: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .zmeCollapsedWhitespace
    }
}

func candidateID() -> String {
    UUID().uuidString.lowercased()
}

func encodedJSONString<T: Encodable>(_ value: T) -> String? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(value) else { return nil }
    return String(data: data, encoding: .utf8)
}

func jaccardTitleSimilarity(_ lhs: String, _ rhs: String) -> Double {
    let a = Set(lhs.zmeNormalized.split(separator: " ").map(String.init).filter { $0.count > 1 })
    let b = Set(rhs.zmeNormalized.split(separator: " ").map(String.init).filter { $0.count > 1 })
    if a.isEmpty || b.isEmpty { return 0 }
    let intersection = a.intersection(b).count
    let union = a.union(b).count
    return union == 0 ? 0 : Double(intersection) / Double(union)
}

func existingValue(for field: String, in item: ItemSnapshot) -> String {
    if field == "creators" {
        return item.creators.map { [$0.firstName, $0.lastName].filter { !$0.isEmpty }.joined(separator: " ") }.joined(separator: "; ")
    }
    if field == "tags" {
        return item.tags.joined(separator: "; ")
    }
    return item.fields[field] ?? ""
}

func isMeaningfullyDifferent(field: String, candidateValue: String, item: ItemSnapshot) -> Bool {
    let current = existingValue(for: field, in: item)
    if current.isEmpty { return !candidateValue.zmeTrimmed.isEmpty }
    return current.zmeNormalized != candidateValue.zmeNormalized
}

private let lowInformationMetadataValues: Set<String> = [
    "-", "—", "n a", "na", "none", "null", "undefined", "unknown",
    "not available", "not applicable", "unavailable", "unspecified",
    "unpublished", "not published", "untitled"
]

func isUsefulMetadataValue(field: String, value: String) -> Bool {
    let trimmed = value.zmeCollapsedWhitespace
    guard !trimmed.isEmpty else { return false }

    let normalized = trimmed.zmeNormalized
    guard !normalized.isEmpty, !lowInformationMetadataValues.contains(normalized) else {
        return false
    }

    // Field-specific placeholders that are especially harmful when written as
    // bibliographic facts. A source may legitimately use these internally, but
    // they do not enrich a Zotero record.
    if field == "publisher" && ["unpublished", "not published"].contains(normalized) {
        return false
    }

    return true
}

func dateComponents(_ raw: String) -> [String] {
    raw.split(whereSeparator: { !$0.isNumber }).map(String.init)
}

func candidateReducesExistingSpecificity(field: String, candidateValue: String, item: ItemSnapshot) -> Bool {
    let current = existingValue(for: field, in: item).zmeCollapsedWhitespace
    guard !current.isEmpty else { return false }

    if field == "date" {
        let currentParts = dateComponents(current)
        let candidateParts = dateComponents(candidateValue)
        if let currentYear = currentParts.first,
           let candidateYear = candidateParts.first,
           currentYear == candidateYear,
           candidateParts.count < currentParts.count {
            return true
        }
    }

    return false
}

func shouldProposeCandidate(field: String, candidateValue: String, item: ItemSnapshot) -> Bool {
    guard isUsefulMetadataValue(field: field, value: candidateValue) else { return false }
    guard isMeaningfullyDifferent(field: field, candidateValue: candidateValue, item: item) else { return false }
    guard !candidateReducesExistingSpecificity(field: field, candidateValue: candidateValue, item: item) else { return false }
    return true
}
