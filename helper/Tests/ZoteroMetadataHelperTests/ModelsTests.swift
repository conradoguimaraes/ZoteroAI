import XCTest
@testable import ZoteroMetadataHelper

final class ModelsTests: XCTestCase {
    func testWhitespaceNormalization() {
        XCTAssertEqual("  Vision\n based   guidance ".zmeCollapsedWhitespace, "Vision based guidance")
    }

    func testNormalizedTextIgnoresCaseAndPunctuation() {
        XCTAssertEqual("Deep-Reinforcement Learning!".zmeNormalized, "deep reinforcement learning")
    }

    func testTitleSimilarityForEquivalentTitles() {
        let score = jaccardTitleSimilarity(
            "Vision-Based Landmark Tracking and Guidance",
            "Vision based landmark tracking & guidance"
        )
        XCTAssertGreaterThan(score, 0.95)
    }

    func testDifferenceDetectionDoesNotProposeIdenticalValue() {
        let item = ItemSnapshot(
            itemID: 1,
            itemKey: "ABCDEFGH",
            libraryID: 1,
            itemType: "journalArticle",
            fields: ["title": "Example Paper"],
            creators: [],
            tags: []
        )
        XCTAssertFalse(isMeaningfullyDifferent(field: "title", candidateValue: "example paper", item: item))
        XCTAssertTrue(isMeaningfullyDifferent(field: "title", candidateValue: "Different Paper", item: item))
    }

    func testRejectsLowInformationPublisherPlaceholder() {
        let item = ItemSnapshot(
            itemID: 1,
            itemKey: "ABCDEFGH",
            libraryID: 1,
            itemType: "journalArticle",
            fields: [:],
            creators: [],
            tags: []
        )
        XCTAssertFalse(shouldProposeCandidate(field: "publisher", candidateValue: "Unpublished", item: item))
        XCTAssertFalse(shouldProposeCandidate(field: "publisher", candidateValue: "Unknown", item: item))
        XCTAssertTrue(shouldProposeCandidate(field: "publisher", candidateValue: "IEEE", item: item))
    }

    func testDoesNotReplacePreciseDateWithYearOnly() {
        let item = ItemSnapshot(
            itemID: 1,
            itemKey: "ABCDEFGH",
            libraryID: 1,
            itemType: "journalArticle",
            fields: ["date": "2020-08-31"],
            creators: [],
            tags: []
        )
        XCTAssertFalse(shouldProposeCandidate(field: "date", candidateValue: "2020", item: item))
        XCTAssertTrue(shouldProposeCandidate(field: "date", candidateValue: "2021", item: item))
    }

    func testCombinedCandidatesCorroborateExactAgreement() {
        let item = ItemSnapshot(
            itemID: 1,
            itemKey: "ABCDEFGH",
            libraryID: 1,
            itemType: "journalArticle",
            fields: [:],
            creators: [],
            tags: []
        )
        let pdf = MetadataCandidate(
            id: "pdf",
            field: "DOI",
            value: "10.1234/example",
            structuredValue: nil,
            source: "Stored PDF (DOI pattern)",
            status: .pdfExtracted,
            evidence: "10.1234/example",
            confidence: 0.99
        )
        let online = MetadataCandidate(
            id: "online",
            field: "DOI",
            value: "10.1234/example",
            structuredValue: nil,
            source: "Crossref",
            status: .verified,
            evidence: "Matched using the item's DOI.",
            confidence: 0.95
        )

        let result = CandidateCombiner.combine(pdf: [pdf], online: [online], item: item)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].status, .corroborated)
        XCTAssertTrue(result[0].source.contains("Stored PDF"))
        XCTAssertTrue(result[0].source.contains("Crossref"))
    }

    func testCombinedCandidatesKeepConflictingAlternativesSeparate() {
        let item = ItemSnapshot(
            itemID: 1,
            itemKey: "ABCDEFGH",
            libraryID: 1,
            itemType: "journalArticle",
            fields: [:],
            creators: [],
            tags: []
        )
        let pdf = MetadataCandidate(
            id: "pdf",
            field: "date",
            value: "2020-08-31",
            structuredValue: nil,
            source: "Apple Intelligence — stored PDF only",
            status: .aiFromPDF,
            evidence: "Front matter",
            confidence: 0.72
        )
        let online = MetadataCandidate(
            id: "online",
            field: "date",
            value: "2020",
            structuredValue: nil,
            source: "OpenAlex",
            status: .online,
            evidence: "Online record",
            confidence: 0.80
        )

        let result = CandidateCombiner.combine(pdf: [pdf], online: [online], item: item)
        XCTAssertEqual(result.count, 2)
    }

}
