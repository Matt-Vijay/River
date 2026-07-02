import Messages
import GameCore

extension MessagesViewController {
    func createLobby(conversation: MSConversation) {
        send(messageActions.newLobby(heroID: heroID(conversation),
                                     name: profile.name,
                                     avatar: profile.avatar),
             conversation: conversation)
    }

    func lobbyJoin(_ lobby: Lobby, conversation: MSConversation) {
        send(messageActions.joinLobby(name: profile.name, avatar: profile.avatar),
             on: .lobby(lobby), conversation: conversation)
    }

    func lobbyToggleReady(_ lobby: Lobby, conversation: MSConversation) {
        send(messageActions.toggleReady(in: lobby,
                                        heroID: heroID(conversation)),
             on: .lobby(lobby), conversation: conversation)
    }

    func commit(_ action: PlayerAction, on state: GameState, conversation: MSConversation) {
        send(messageActions.gameAction(action), on: .game(state), conversation: conversation)
    }

    func joinGame(_ state: GameState, conversation: MSConversation) {
        send(messageActions.joinGame(name: profile.name, avatar: profile.avatar),
             on: .game(state), conversation: conversation)
    }

    func leaveGame(_ state: GameState, conversation: MSConversation) {
        send(messageActions.leaveGame(), on: .game(state), conversation: conversation)
    }

    func leaveLobby(_ lobby: Lobby, conversation: MSConversation) {
        send(messageActions.leaveLobby(), on: .lobby(lobby), conversation: conversation)
    }

    func dealNextHand(from state: GameState, conversation: MSConversation) {
        send(messageActions.dealNextHand(),
             on: .game(state), conversation: conversation)
    }
}
