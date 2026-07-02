import Foundation

extension GameState {
    mutating func openFirstBettingRound(playingCount: Int, now: Date) {
        let blinds = blindSeats(playingCount: playingCount)
        if let smallBlindSeat = blinds.smallBlind {
            postBlind(smallBlindSeat, amount: smallBlind)
        }
        if let bigBlindSeat = blinds.bigBlind {
            postBlind(bigBlindSeat, amount: bigBlind)
        }
        currentToAct = blinds.firstToAct
        turnStartedAt = now
    }
}
