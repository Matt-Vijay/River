import Foundation

public struct LegalBet: Equatable, Sendable {
    public let call: Int
    public let raise: ClosedRange<Int>?
    public var canCheck: Bool { call == 0 }

    func allows(_ bet: Bet) -> Bool {
        switch bet {
        case .fold: true
        case .check: canCheck
        case .call: call > 0
        case .raiseTo(let total): raise?.contains(total) == true
        }
    }
}

extension Table {
    public func legalBet(for id: String, at date: Date = Date()) -> LegalBet? {
        guard let hand, !hand.isComplete, hand.turn == id, hand.remaining(at: date) > 0,
              let seat = seat(id), seat.isEligible, let stake = stake(id), !stake.folded else { return nil }
        let bet = currentBet
        let due = bet - stake.bet
        let maximum = stake.bet + seat.chips
        let reopened = stake.actedAtBet.map { bet - $0 >= hand.raiseIncrement } ?? true
        let minimum = min(bet + hand.raiseIncrement, maximum)
        let canRespond = hand.stakes.contains { $0.id != id && !$0.folded && self.seat($0.id)?.isEligible == true }
        let raise = canRespond && reopened && maximum > bet ? minimum...maximum : nil
        return LegalBet(call: min(due, seat.chips), raise: raise)
    }

    /// All actions are transactions: failure leaves the original snapshot untouched.
    public func applying(_ action: Action, by actor: String, at date: Date = Date()) throws -> Table {
        guard Self.validID(actor) else { throw TableError.invalidPlayer }
        guard version < 1_000_000_000, date.timeIntervalSince1970.isFinite,
              (0...253_402_300_000).contains(date.timeIntervalSince1970) else { throw TableError.invalidState }
        var next = self
        switch action {
        case .join(let profile): try next.join(actor, profile: profile)
        case .leave: try next.leave(actor, at: date)
        case .deal(let seed):
            guard seat(actor)?.isEligible == true else { throw TableError.invalidPlayer }
            guard canDeal else { throw TableError.cannotDeal }
            guard (hand?.number ?? 0) < 1_000_000_000 else { throw TableError.invalidState }
            next.deal(seed: seed, at: date)
        case .bet(let bet):
            guard let hand, !hand.isComplete else { throw TableError.finished }
            guard hand.turn == actor else { throw TableError.notYourTurn }
            guard hand.remaining(at: date) > 0 else { throw TableError.expired }
            guard legalBet(for: actor, at: date)?.allows(bet) == true else { throw TableError.illegalBet }
            next.bet(bet, by: actor, at: date)
        case .timeout:
            guard let seat = seat(actor), !seat.hasLeft else { throw TableError.invalidPlayer }
            guard let hand, !hand.isComplete, hand.remaining(at: date) == 0,
                  let turn = hand.turn, let stake = stake(turn) else { throw TableError.illegalBet }
            next.bet(stake.bet == currentBet ? .check : .fold, by: turn, at: date)
        }
        if next != self { next.version = version + 1 }
        return next
    }

    private mutating func join(_ id: String, profile: Profile) throws {
        guard Profile(name: profile.name, avatar: profile.avatar) == profile else { throw TableError.invalidPlayer }
        guard !isFinished else { throw TableError.finished }
        if let index = seats.firstIndex(where: { $0.id == id }) {
            guard seats[index].hasLeft || (hand?.isComplete == true && seats[index].chips == 0) else { return }
            seats[index].hasLeft = false
            seats[index].profile = profile
            if (hand?.isComplete != false || stake(id) == nil), seats[index].chips == 0 {
                guard chipTotal <= Rules.chipLimit - rules.buyIn else { throw TableError.tableFull }
                seats[index].chips = rules.buyIn
            }
        } else {
            guard seats.count < rules.capacity else { throw TableError.tableFull }
            guard chipTotal <= Rules.chipLimit - rules.buyIn else { throw TableError.tableFull }
            seats.append(Seat(id: id, profile: profile, chips: rules.buyIn))
        }
    }

    private mutating func leave(_ id: String, at date: Date) throws {
        guard let index = seats.firstIndex(where: { $0.id == id }), !seats[index].hasLeft else {
            throw TableError.invalidPlayer
        }
        guard hand != nil else {
            seats.remove(at: index)
            return
        }
        guard !isFinished else { throw TableError.finished }
        seats[index].hasLeft = true
        guard hand?.isComplete == false, seats[index].chips > 0,
              let stakeIndex = hand?.stakes.firstIndex(where: { $0.id == id }),
              hand?.stakes[stakeIndex].folded == false else { return }
        hand?.stakes[stakeIndex].folded = true
        hand?.stakes[stakeIndex].lastAction = .fold
        let previous = hand?.turn ?? id
        advance(after: previous, at: date, preserveTurn: previous != id)
    }

    private mutating func deal(seed: UInt64, at date: Date) {
        let eligible = eligibleSeats
        let dealer: String
        if let previous = hand {
            if eligible.count == 2, eligible.contains(where: { $0.id == previous.bigBlindID }) {
                dealer = previous.bigBlindID
            } else {
                let start = seats.firstIndex { $0.id == previous.dealerID } ?? 0
                dealer = (1...seats.count).map { seats[(start + $0) % seats.count] }
                    .first(where: \.isEligible)!.id
            }
        } else {
            dealer = eligible[0].id
        }
        seats = eligible
        let button = seats.firstIndex { $0.id == dealer }!
        let order = (1...seats.count).map { seats[(button + $0) % seats.count].id }
        hand = Hand(number: (hand?.number ?? 0) + 1, dealerID: dealer,
                    deck: Card.deck(seed: seed), stakes: order.map { Hand.Stake(id: $0) },
                    raiseIncrement: rules.bigBlind)
        pay(hand!.smallBlindID, amount: rules.smallBlind)
        pay(hand!.bigBlindID, amount: rules.bigBlind)
        advance(after: hand!.bigBlindID, at: date)
    }

    private mutating func bet(_ bet: Bet, by actor: String, at date: Date) {
        let index = hand!.stakes.firstIndex { $0.id == actor }!
        let oldBet = currentBet
        switch bet {
        case .fold: hand?.stakes[index].folded = true
        case .check: break
        case .call: pay(actor, amount: oldBet - hand!.stakes[index].bet)
        case .raiseTo(let total):
            pay(actor, amount: total - hand!.stakes[index].bet)
            let increment = max(hand!.raiseIncrement, total - oldBet)
            hand?.raiseIncrement = increment
        }
        let actedAt = hand!.stakes[index].bet
        hand?.stakes[index].actedAtBet = actedAt
        hand?.stakes[index].lastAction = bet
        advance(after: actor, at: date)
    }

    private mutating func pay(_ id: String, amount: Int) {
        let seat = seats.firstIndex { $0.id == id }!
        let stake = hand!.stakes.firstIndex { $0.id == id }!
        let paid = min(max(0, amount), seats[seat].chips)
        seats[seat].chips -= paid
        hand?.stakes[stake].bet += paid
        hand?.stakes[stake].committed += paid
    }

    private mutating func advance(after id: String, at date: Date, preserveTurn: Bool = false) {
        guard let current = hand, !current.isComplete else { return }
        let expires = deadline(at: date)
        if current.contenders.count == 1 { finish(); return }
        let active = current.stakes.filter { !$0.folded && seat($0.id)?.isEligible == true }
        let bet = currentBet
        // With nobody able to respond, only an actual outstanding bet needs action.
        let pending = active.filter {
            $0.bet < bet || (active.count > 1 && $0.actedAtBet != bet)
        }
        if !pending.isEmpty {
            if preserveTurn, pending.contains(where: { $0.id == current.turn }) { return }
            let start = current.stakes.firstIndex { $0.id == id } ?? 0
            let next = (1...current.stakes.count).map { current.stakes[(start + $0) % current.stakes.count] }
                .first { candidate in pending.contains(where: { $0.id == candidate.id }) }!
            hand?.turn = next.id
            hand?.deadline = expires
        } else if active.count <= 1 || current.street == .river {
            hand?.street = .river
            finish()
        } else {
            hand?.street = Hand.Street(rawValue: current.street.rawValue + 1)!
            hand?.raiseIncrement = rules.bigBlind
            for index in current.stakes.indices {
                hand?.stakes[index].bet = 0
                hand?.stakes[index].actedAtBet = nil
                hand?.stakes[index].lastAction = nil
            }
            hand?.turn = active[0].id
            hand?.deadline = expires
        }
    }

    private func deadline(at date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded(.down)) + Int64(rules.turnSeconds * 1_000)
    }

    private mutating func finish() {
        for award in settlement() {
            let index = seats.firstIndex { $0.id == award.id }!
            seats[index].chips += award.won + award.refund
        }
        hand?.isComplete = true
        hand?.turn = nil
        hand?.deadline = nil
        hand?.raiseIncrement = 0
        for index in hand!.stakes.indices {
            hand?.stakes[index].bet = 0
            hand?.stakes[index].actedAtBet = nil
        }
    }
}
