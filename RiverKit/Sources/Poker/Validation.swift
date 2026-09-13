import Foundation

extension Table {
    /// Validation is a transport boundary, not a second implementation of the game.
    public func validated() throws -> Table {
        guard Self.validID(id), (0...1_000_000_000).contains(version),
              (2...6).contains(rules.capacity), (1...Rules.chipLimit / 6).contains(rules.buyIn),
              (1...rules.buyIn).contains(rules.smallBlind),
              (rules.smallBlind...Rules.chipLimit / 6).contains(rules.bigBlind),
              (1...300).contains(rules.turnSeconds), seats.count <= rules.capacity,
              Set(seats.map(\.id)).count == seats.count else { throw TableError.invalidState }
        for seat in seats {
            guard Self.validID(seat.id), Profile(name: seat.profile.name, avatar: seat.profile.avatar) == seat.profile,
                  (0...Rules.chipLimit).contains(seat.chips) else { throw TableError.invalidState }
        }
        guard let hand else {
            guard seats.allSatisfy({ !$0.hasLeft && $0.chips == rules.buyIn }) else { throw TableError.invalidState }
            return self
        }
        guard (1...1_000_000_000).contains(hand.number), hand.deck.count == 52,
              Set(hand.deck).count == 52, (2...rules.capacity).contains(hand.stakes.count),
              Set(hand.stakes.map(\.id)).count == hand.stakes.count,
              hand.stakes.last?.id == hand.dealerID,
              hand.contenders.count >= 1 else { throw TableError.invalidState }
        let dealer = seats.firstIndex { $0.id == hand.dealerID }
        guard let dealer else { throw TableError.invalidState }
        let expectedOrder = (1...seats.count).map { seats[(dealer + $0) % seats.count].id }
            .filter { id in hand.stakes.contains(where: { $0.id == id }) }
        guard expectedOrder == hand.stakes.map(\.id) else { throw TableError.invalidState }
        for stake in hand.stakes {
            guard let seat = seat(stake.id), (0...Rules.chipLimit).contains(stake.committed),
                  (0...stake.committed).contains(stake.bet),
                  stake.actedAtBet == nil || stake.actedAtBet == stake.bet,
                  !seat.hasLeft || stake.folded || seat.chips == 0 || hand.isComplete else {
                throw TableError.invalidState
            }
            if case .raiseTo(let total) = stake.lastAction {
                guard (1...Rules.chipLimit).contains(total) else { throw TableError.invalidState }
            }
        }
        guard chipTotal <= Rules.chipLimit else { throw TableError.invalidState }
        if hand.isComplete {
            guard hand.turn == nil, hand.deadline == nil, hand.raiseIncrement == 0,
                  hand.stakes.allSatisfy({ $0.bet == 0 && $0.actedAtBet == nil }),
                  hand.contenders.count == 1 || hand.street == .river,
                  awards.allSatisfy({ (seat($0.id)?.chips ?? 0) >= $0.won + $0.refund }) else {
                throw TableError.invalidState
            }
        } else {
            guard hand.contenders.count >= 2, let turn = hand.turn, let stake = stake(turn),
                  !stake.folded, seat(turn)?.isEligible == true,
                  let deadline = hand.deadline, (1...253_402_300_300_000).contains(deadline),
                  (rules.bigBlind...Rules.chipLimit).contains(hand.raiseIncrement) else {
                throw TableError.invalidState
            }
            let canRespond = hand.stakes.contains { $0.id != turn && !$0.folded && seat($0.id)?.isEligible == true }
            guard stake.bet < currentBet || (canRespond && stake.actedAtBet != currentBet) else {
                throw TableError.invalidState
            }
        }
        return self
    }
}
