import GameCore

extension RenderScenarios {
    static func lobby() -> Lobby {
        Lobby(seats: [
            LobbySeat(id: "dante", name: "dante", avatar: "🧑🏿", isReady: true),
            LobbySeat(id: "you", name: "you", avatar: "🦊", isReady: false),
            LobbySeat(id: "verbice", name: "verbice", avatar: "🐱", isReady: true),
        ])
    }
}
