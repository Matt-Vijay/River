enum HoldemAccessibility {
    enum Conversation {
        static let sendTable = "conversation.sendTable"
        static let joinGame = "conversation.joinGame"
        static let tableFull = "conversation.tableFull"
        static let gameOver = "conversation.gameOver"
        static let openTable = "conversation.openTable"
        static let recovery = "conversation.recovery"
        static let closeRecovery = "conversation.recovery.close"
    }

    enum Profile {
        static let nameField = "profile.name"
        static let save = "profile.save"
        static func avatar(_ index: Int) -> String {
            "profile.avatar.\(index)"
        }
    }

    enum Lobby {
        static let localSeat = "lobby.localSeat"
        static let startGame = "lobby.startGame"
        static let leave = "lobby.leave"
        static let cancelLeave = "lobby.leave.cancel"
        static let confirmLeave = "lobby.leave.confirm"
        static let addPlayer = "lobby.addPlayer"
    }

    enum Table {
        static let handoff = "table.handoff"
        static let revealHand = "table.handoff.reveal"
        static let leave = "table.leave"
        static let cancelLeave = "table.leave.cancel"
        static let confirmLeave = "table.leave.confirm"
        static let waiting = "table.waiting"
        static let board = "table.board"
        static let pot = "table.pot"
        static let result = "table.result"
        static let dealNext = "table.action.dealNext"
        static let newTable = "table.action.newTable"
        static let holeCards = "table.holeCards"
        static let heroSeat = "table.heroSeat"
        static let fold = "table.action.fold"
        static let check = "table.action.check"
        static let call = "table.action.call"
        static let allIn = "table.action.allIn"
        static let expandRaise = "table.action.raise.expand"
        static let raiseSlider = "table.raise.slider"
        static let submitRaise = "table.raise.submit"
        static let closeRaise = "table.raise.close"
        static let resolveTimeout = "table.timeout.resolve"

        static func raisePreset(_ name: String) -> String {
            "table.raise.preset.\(name)"
        }
    }
}
