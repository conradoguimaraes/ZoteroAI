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
}
