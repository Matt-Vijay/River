import Foundation
import Testing
@testable import Poker

@Suite("Poker contract")
struct TableTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func seated(_ chips: [Int] = [1_000, 1_000, 1_000]) throws -> Table {
        var table = Table(id: "test")
        for index in chips.indices {
            table = try table.applying(.join(Profile(name: "Player \(index)", avatar: "A")!), by: "p\(index)", at: now)
            table.seats[index].chips = chips[index]
        }
        return table
    }

    func act(_ bet: Bet, on table: Table) throws -> Table {
        try table.applying(.bet(bet), by: #require(table.hand?.turn), at: now)
    }

    @Test func completeHand() throws {
        var table = Table(id: "test")
        for index in 0..<3 {
            table = try table.applying(.join(Profile(name: "Player \(index)", avatar: "A")!),
                                       by: "p\(index)", at: now)
        }
        table = try table.applying(.deal(seed: 42), by: "p0", at: now)
        #expect(table.hand?.turn == "p0")
        for _ in 0..<30 where table.hand?.isComplete == false {
            let actor = try #require(table.hand?.turn)
            let legal = try #require(table.legalBet(for: actor, at: now))
            table = try table.applying(.bet(legal.canCheck ? .check : .call), by: actor, at: now)
            _ = try table.validated()
        }
        #expect(table.hand?.isComplete == true)
        #expect(table.chipTotal == 3_000)
        #expect(table.hand?.board.count == 5)
    }

    @Test func turnMustStillNeedAction() throws {
        var table = try seated().applying(.deal(seed: 42), by: "p0", at: now)
        table = try act(.call, on: table)
        #expect(table.hand?.turn == "p1")
        _ = try table.validated()
        table.hand?.turn = "p0"
        #expect(throws: TableError.invalidState) { try table.validated() }
    }

    @Test func blindsAndHeadsUpOrder() throws {
        var table = try seated([1_000, 1_000]).applying(.deal(seed: 1), by: "p0", at: now)
        #expect(table.hand?.smallBlindID == "p0")
        #expect(table.hand?.bigBlindID == "p1")
        #expect(table.hand?.turn == "p0")
        table = try act(.call, on: table)
        #expect(table.hand?.turn == "p1")
        table = try act(.check, on: table)
        #expect(table.hand?.street == .flop)
        #expect(table.hand?.turn == "p1")
        table = try act(.fold, on: table)
        table = try table.applying(.deal(seed: 2), by: "p0", at: now)
        #expect(table.hand?.dealerID == "p1")
        #expect(table.chipTotal == 2_000)
    }

    @Test func shortBlindRunsOutWithoutUncontestedBetting() throws {
        let complete = try seated([100, 3]).applying(.deal(seed: 3), by: "p0", at: now)
        #expect(complete.hand?.isComplete == true)
        #expect(complete.chipTotal == 103)
        #expect(complete.awards.reduce(0) { $0 + $1.won } == 6)
        #expect(complete.awards.reduce(0) { $0 + $1.refund } == 2)
        _ = try complete.validated()

        let facingAllIn = try seated([3, 100]).applying(.deal(seed: 4), by: "p0", at: now)
        #expect(facingAllIn.hand?.isComplete == true)
        #expect(facingAllIn.chipTotal == 103)

        var shortBlind = try seated([100, 7]).applying(.deal(seed: 5), by: "p0", at: now)
        #expect(shortBlind.legalBet(for: "p0", at: now)?.call == 2)
        #expect(shortBlind.legalBet(for: "p0", at: now)?.raise == nil)
        shortBlind = try act(.call, on: shortBlind)
        #expect(shortBlind.hand?.isComplete == true)
        #expect(shortBlind.hand?.pot == 14)
    }

    @Test func shortRaisesAndRaiseReopening() throws {
        var table = try seated([1_000, 25, 1_000]).applying(.deal(seed: 1), by: "p0", at: now)
        table = try act(.raiseTo(20), on: table)
        table = try act(.raiseTo(25), on: table)
        #expect(table.legalBet(for: "p2", at: now)?.raise == 35...1_000)
        table = try act(.call, on: table)
        #expect(table.legalBet(for: "p0", at: now)?.raise == nil)
        #expect(throws: TableError.illegalBet) { try act(.raiseTo(35), on: table) }
        table = try act(.call, on: table)
        #expect(table.hand?.street == .flop)
        #expect(table.chipTotal == 2_025)

        table = try seated([1_000, 1_000, 1_000]).applying(.deal(seed: 2), by: "p0", at: now)
        table = try act(.raiseTo(30), on: table)
        table = try act(.raiseTo(60), on: table)
        table = try act(.call, on: table)
        #expect(table.legalBet(for: "p0", at: now)?.raise == 90...1_000)
    }

    @Test func noRaiseIntoAnAllInOpponent() throws {
        var table = try seated([100, 100]).applying(.deal(seed: 1), by: "p0", at: now)
        table = try act(.raiseTo(100), on: table)
        #expect(table.legalBet(for: "p1", at: now)?.raise == nil)
        table = try act(.call, on: table)
        #expect(table.hand?.isComplete == true)
        #expect(table.chipTotal == 200)
    }

    @Test func timeoutAndDepartureAreDeterministic() throws {
        var table = try seated().applying(.deal(seed: 7), by: "p0", at: now)
        let deadline = table.hand?.deadline
        table = try table.applying(.leave, by: "p1", at: now.addingTimeInterval(5))
        #expect(table.hand?.turn == "p0")
        #expect(table.hand?.deadline == deadline)
        #expect(throws: TableError.illegalBet) { try table.applying(.timeout, by: "p2", at: now) }
        table = try table.applying(.timeout, by: "p2", at: now.addingTimeInterval(30))
        #expect(table.stake("p0")?.folded == true)
        #expect(table.hand?.isComplete == true)
        #expect(table.chipTotal == 3_000)

        table = try seated().applying(.deal(seed: 8), by: "p0", at: now)
        for _ in 0..<3 { table = try act(table.currentBet == table.stake(table.hand!.turn!)!.bet ? .check : .call, on: table) }
        let turn = table.hand!.turn!
        table = try table.applying(.timeout, by: "p0", at: now.addingTimeInterval(30))
        #expect(table.stake(turn)?.folded == false)
        #expect(table.stake(turn)?.lastAction == .check)
    }

    @Test func allInDepartureAndMidHandJoin() throws {
        var table = try seated([100, 100, 100]).applying(.deal(seed: 11), by: "p0", at: now)
        table = try act(.raiseTo(100), on: table)
        #expect(!table.canJoin("p0"))
        table = try table.applying(.leave, by: "p0", at: now)
        #expect(table.stake("p0")?.folded == false)
        #expect(table.canJoin("p0"))
        let rejoined = try table.applying(.join(Profile(name: "Player 0", avatar: "A")!), by: "p0", at: now)
        #expect(!rejoined.canJoin("p0"))
        #expect(rejoined.seat("p0")?.chips == 0)
        #expect(rejoined.hand == table.hand)
        #expect(table.canJoin("late"))
        table = try table.applying(.join(Profile(name: "Late", avatar: "L")!), by: "late", at: now)
        #expect(!table.canJoin("late"))
        #expect(table.hand?.cards(for: "late").isEmpty == true)
        #expect(table.hand?.stakes.count == 3)
        while table.hand?.isComplete == false { table = try act(.call, on: table) }
        #expect(table.chipTotal == 1_300)
        _ = try table.validated()
    }

    @Test func departingRaiserLeavesNoUncontestedCall() throws {
        var table = try seated([100, 1_000, 1_000]).applying(.deal(seed: 7), by: "p0", at: now)
        table = try act(.raiseTo(100), on: table)
        table = try act(.call, on: table)
        table = try act(.raiseTo(200), on: table)
        table = try table.applying(.leave, by: "p2", at: now)
        #expect(table.hand?.isComplete == true)
        #expect(table.stake("p1")?.folded == false)
        #expect(table.awards.first { $0.id == "p1" }?.won == 300)
        #expect(table.awards.first { $0.id == "p2" }?.refund == 100)
        #expect(table.chipTotal == 2_100)
        _ = try table.validated()
    }

    @Test func departingBlindsForfeitMatchedChips() throws {
        var table = try seated().applying(.deal(seed: 7), by: "p0", at: now)
        table = try table.applying(.leave, by: "p1", at: now)
        table = try table.applying(.leave, by: "p2", at: now)
        #expect(table.hand?.isComplete == true)
        #expect(table.awards.first { $0.id == "p0" }?.won == 10)
        #expect(table.awards.first { $0.id == "p1" }?.refund == 0)
        #expect(table.awards.first { $0.id == "p2" }?.refund == 5)
        #expect(table.chipTotal == 3_000)
        _ = try table.validated()
    }

    @Test func unequalAllInsAndRefunds() throws {
        var table = try seated([100, 200, 300]).applying(.deal(seed: 12), by: "p0", at: now)
        table = try act(.raiseTo(100), on: table)
        table = try act(.raiseTo(200), on: table)
        #expect(table.legalBet(for: "p2", at: now)?.raise == nil)
        table = try act(.call, on: table)
        #expect(table.hand?.isComplete == true)
        #expect(table.hand?.pot == 500)
        #expect(table.awards.reduce(0) { $0 + $1.won + $1.refund } == 500)
        #expect(table.chipTotal == 600)
        _ = try table.validated()
    }

    @Test func foldedContributionsDoNotSplitTiedPot() throws {
        var table = try seated(Array(repeating: 1_000, count: 5))
            .applying(.deal(seed: 3014), by: "p0", at: now)
        let actions: [(String, Bet)] = [
            ("p3", .call), ("p4", .call), ("p0", .call), ("p1", .call), ("p2", .check),
            ("p1", .raiseTo(11)), ("p2", .call), ("p3", .raiseTo(22)),
            ("p4", .call), ("p0", .call), ("p1", .fold), ("p2", .fold),
            ("p3", .check), ("p4", .raiseTo(10)), ("p0", .call), ("p3", .fold),
            ("p4", .check), ("p0", .check),
        ]
        for (actor, bet) in actions {
            table = try table.applying(.bet(bet), by: actor, at: now)
            #expect(table.seats.allSatisfy { $0.chips > 0 })
            _ = try table.validated()
        }
        let hand = try #require(table.hand)
        #expect(hand.isComplete)
        #expect(hand.stakes.map(\.committed) == [21, 21, 32, 42, 42])
        #expect(hand.pot == 158)
        // This seed puts Broadway on the board; neither survivor can improve it.
        #expect(hand.board.map(\.id) == [41, 32, 45, 51, 36])
        let leftOfDealer = try #require(table.awards.first { $0.id == "p4" })
        let dealer = try #require(table.awards.first { $0.id == "p0" })
        #expect(leftOfDealer.hand?.category == .straight)
        #expect(leftOfDealer.hand?.ranks == [14])
        #expect(leftOfDealer.hand == dealer.hand)
        #expect(leftOfDealer.won == 79)
        #expect(dealer.won == 79)
        #expect(table.awards.allSatisfy { $0.refund == 0 })
        #expect(table.seat("p4")?.chips == 1_037)
        #expect(table.seat("p0")?.chips == 1_037)
        #expect(table.chipTotal == 5_000)
    }

    @Test func distinctSidePotWinnersAndOddChips() throws {
        var table = try seated([100, 200, 300])
        // Deal order p1, p2, p0: kings, queens, aces; an unpaired low board.
        let prefix = [44, 40, 48, 45, 41, 49, 0, 5, 22, 31, 36].map { Card(id: $0)! }
        let deck = prefix + (0..<52).compactMap(Card.init(id:)).filter { !prefix.contains($0) }
        table.hand = Hand(number: 1, dealerID: "p0", deck: deck,
            stakes: [Hand.Stake(id: "p1", committed: 200), Hand.Stake(id: "p2", committed: 300),
                     Hand.Stake(id: "p0", committed: 100)], raiseIncrement: 0)
        table.hand?.street = .river
        let awards = table.settlement()
        #expect(awards.first { $0.id == "p0" }?.won == 300)
        #expect(awards.first { $0.id == "p1" }?.won == 200)
        #expect(awards.first { $0.id == "p2" }?.refund == 100)

        let royal = [0, 1, 2, 4, 5, 6, 32, 36, 40, 44, 48].map { Card(id: $0)! }
        table.hand = Hand(number: 1, dealerID: "p0",
            deck: royal + (0..<52).compactMap(Card.init(id:)).filter { !royal.contains($0) },
            stakes: [Hand.Stake(id: "p1", committed: 1), Hand.Stake(id: "p2", committed: 1, folded: true),
                     Hand.Stake(id: "p0", committed: 1)], raiseIncrement: 0)
        table.hand?.street = .river
        #expect(table.settlement().first { $0.id == "p1" }?.won == 2)
        #expect(table.settlement().first { $0.id == "p0" }?.won == 1)

        table.hand?.stakes[0].committed = .max
        #expect(throws: TableError.invalidState) { try table.validated() }
    }

    @Test func seededLegalPlayConservesChipsAndReplays() throws {
        for playerCount in 2...6 {
            var table = try seated(Array(repeating: 1_000, count: playerCount))
            for hand in 1...12 where table.canDeal {
                var message = try TableMessage(recording: .deal(seed: UInt64(hand)), on: table, actor: table.eligibleSeats[0].id, at: now)
                #expect(message.verifies(after: table))
                table = message.table
                var step = 0
                while table.hand?.isComplete == false {
                    step += 1
                    #expect(step < 100)
                    guard step < 100 else { return }
                    let actor = try #require(table.hand?.turn)
                    let legal = try #require(table.legalBet(for: actor, at: now))
                    let bet: Bet = step % 7 == 0 ? .fold : step % 5 == 0 && legal.raise != nil
                        ? .raiseTo(legal.raise!.lowerBound) : legal.canCheck ? .check : .call
                    message = try TableMessage(recording: .bet(bet), on: table, actor: actor, at: now)
                    let decoded = try TableMessage(url: message.url())
                    #expect(decoded.verifies(after: table))
                    table = decoded.table
                    #expect(table.chipTotal == playerCount * 1_000)
                }
            }
        }
    }
}
