import GameCore

struct PokerTablePresentation {
    enum ActionMode: String {
        case gameOver
        case dealNext
        case act
        case wait
    }

    let state: GameState
    let heroID: String
    let canDealNext: Bool
}
