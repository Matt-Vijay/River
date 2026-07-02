enum HoldemAccessibility {
    enum Conversation {
        static let startTable = "conversation.startTable"
        static let joinGame = "conversation.joinGame"
        static let gameOver = "conversation.gameOver"
        static let openTable = "conversation.openTable"
        static let recovery = "conversation.recovery"
        static let profileSummary = "conversation.profileSummary"
        static let editProfile = "conversation.editProfile"
    }

    enum Profile {
        static let nameField = "profile.name"
        static let save = "profile.save"
        static let cancel = "profile.cancel"

        static func avatar(_ index: Int) -> String {
            "profile.avatar.\(index)"
        }
    }

    enum Lobby {
        static let profileSummary = "lobby.profileSummary"
        static let editProfile = "lobby.editProfile"
        static let join = "lobby.join"
        static let ready = "lobby.ready"
        static let leave = "lobby.leave"
        static let addTestPlayer = "lobby.addTestPlayer"
    }

    enum Table {
        static let leave = "table.leave"
        static let cancelLeave = "table.leave.cancel"
        static let confirmLeave = "table.leave.confirm"
        static let waiting = "table.waiting"
        static let board = "table.board"
        static let pot = "table.pot"
        static let result = "table.result"
        static let dealNext = "table.action.dealNext"
        static let holeCards = "table.holeCards"
        static let heroSeat = "table.heroSeat"
        static let fold = "table.action.fold"
        static let check = "table.action.check"
        static let call = "table.action.call"
        static let minRaise = "table.action.raise.min"
        static let expandRaise = "table.action.raise.expand"
        static let raiseSlider = "table.raise.slider"
        static let submitRaise = "table.raise.submit"
        static let closeRaise = "table.raise.close"

        static func raisePreset(_ name: String) -> String {
            "table.raise.preset.\(name)"
        }
    }
}
