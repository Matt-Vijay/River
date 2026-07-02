extension GameState {
    typealias BlindSeats = (smallBlind: Int?, bigBlind: Int?, firstToAct: Int?)

    func blindSeats(playingCount: Int) -> BlindSeats {
        if playingCount == 2 {
            return (
                smallBlind: dealerIndex,
                bigBlind: nextSeat(after: dealerIndex) { $0.status == .active },
                firstToAct: dealerIndex
            )
        }

        let smallBlind = nextSeat(after: dealerIndex) { $0.status == .active }
        let bigBlind = smallBlind.flatMap { nextSeat(after: $0) { $0.status == .active } }
        let firstToAct = bigBlind.flatMap { nextSeat(after: $0) { $0.status == .active } }
        return (smallBlind, bigBlind, firstToAct)
    }
}
