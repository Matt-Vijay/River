import Testing
import Foundation
@testable import GameCore

@Suite("Hand results")
struct HandResultTests {
    @Test("result construction normalizes winnings and best five")
    func constructionNormalizesWinningsAndBestFive() {
        let malformed = HandResult(playerID: "p0", amountWon: -10,
                                   handName: "Flush",
                                   bestFive: cards("Ah Kh Qh"))
        let valid = HandResult(playerID: "p1", amountWon: 20,
                               handName: "Straight",
                               bestFive: cards("Ah Kh Qh Jh Th"))

        #expect(malformed.amountWon == 0)
        #expect(malformed.bestFive == nil)
        #expect(valid.bestFive?.count == 5)
    }

    @Test("result player identities are trimmed and blank identities are replaced")
    func resultPlayerIdentitiesAreTrimmedAndBlankIdentitiesAreReplaced() {
        let padded = HandResult(playerID: "  p0  ", amountWon: 10,
                                handName: nil, bestFive: nil)
        let blank = HandResult(playerID: "   ", amountWon: 10,
                               handName: nil, bestFive: nil)

        #expect(padded.playerID == "p0")
        #expect(!blank.playerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test("decoded results normalize best five")
    func decodedResultsNormalizeBestFive() throws {
        var result = HandResult(playerID: "p0", amountWon: 10,
                                handName: "Pair",
                                bestFive: cards("Ah Kh Qh Jh Th"))
        result.bestFive = cards("Ah Kh")

        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(HandResult.self, from: data)

        #expect(decoded.bestFive == nil)
    }
}
