import Foundation

public struct Award: Identifiable, Sendable {
    public let id: String
    public internal(set) var won = 0
    public internal(set) var refund = 0
    public let hand: HandValue?
}

extension Table {
    public var awards: [Award] { hand?.isComplete == true ? settlement() : [] }

    func settlement() -> [Award] {
        guard let hand else { return [] }
        var awards = hand.stakes.map { stake in
            Award(id: stake.id, hand: !stake.folded && hand.contenders.count > 1
                  ? HandValue.best(hand.cards(for: stake.id) + hand.board) : nil)
        }
        let contenders = hand.stakes.indices.filter { !hand.stakes[$0].folded }
        var previous = 0
        var amount = 0
        for level in Set(hand.stakes.map(\.committed)).sorted() where level > 0 {
            let contributors = hand.stakes.indices.filter { hand.stakes[$0].committed >= level }
            let eligible = contenders.count == 1 ? contenders : contributors.filter { !hand.stakes[$0].folded }
            amount += (level - previous) * contributors.count
            previous = level
            let refund = contributors.count == 1 || eligible.isEmpty
            let remaining = contributors.filter { hand.stakes[$0].committed > level }
            let nextEligible = contenders.count == 1 ? contenders : remaining.filter { !hand.stakes[$0].folded }
            // Folded contributions do not split a pot; eligibility changes and refunds do.
            if !refund && remaining.count > 1 && nextEligible == eligible { continue }
            let best = eligible.compactMap { awards[$0].hand }.max()
            let winners = refund ? contributors : eligible.filter { awards[$0].hand == best }
            for (offset, index) in winners.enumerated() {
                let share = amount / winners.count + (offset < amount % winners.count ? 1 : 0)
                if refund { awards[index].refund += share }
                else { awards[index].won += share }
            }
            amount = 0
        }
        return awards
    }
}
