import Foundation

extension GameState {
    /// Deals a fresh hand. Players with chips are dealt in; busted players sit out.
    public static func startHand(
        players input: [Player],
        dealerIndex: Int,
        smallBlind: Int,
        bigBlind: Int,
        seed: UInt64,
        handNumber: Int,
        tableID: String = UUID().uuidString,
        appliedOperationIDs: [String] = [],
        turnDuration: TimeInterval = TurnClock.defaultDuration,
        now: Date = Date()
    ) -> GameState {
        let dealerIndex = normalizedSeat(dealerIndex, playerCount: input.count)
        let blinds = BlindStructure.normalized(smallBlind: smallBlind, bigBlind: bigBlind)
        let smallBlind = blinds.smallBlind
        let bigBlind = blinds.bigBlind
        let handNumber = max(1, handNumber)
        let turnDuration = TurnClock.normalized(turnDuration)
        var players = preparedPlayersForNewHand(input)
        var deck = Deck.shuffled(seed: seed).cards
        let dealOrder = dealOrder(players: players, dealerIndex: dealerIndex)
        dealHoleCards(to: &players, deck: &deck, dealOrder: dealOrder)

        var state = GameState(
            tableID: tableID,
            appliedOperationIDs: appliedOperationIDs,
            handNumber: handNumber,
            players: players,
            dealerIndex: dealerIndex,
            smallBlind: smallBlind,
            bigBlind: bigBlind,
            board: [],
            deck: deck,
            pot: 0,
            street: .preflop,
            currentToAct: nil,
            currentBet: bigBlind,
            minRaise: bigBlind,
            turnStartedAt: now,
            turnDuration: turnDuration,
            results: nil,
            version: 0
        )

        state.openFirstBettingRound(playingCount: dealOrder.count, now: now)
        return state
    }
}
