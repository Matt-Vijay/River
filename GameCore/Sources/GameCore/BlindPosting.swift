extension GameState {
    mutating func postBlind(_ index: Int, amount: Int) {
        pay(index, additional: amount)
    }
}
