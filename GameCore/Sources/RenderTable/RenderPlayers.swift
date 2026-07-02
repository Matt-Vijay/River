import GameCore

extension RenderScenarios {
    static func samplePlayers() -> [Player] {
        [
            Player(id: "dante", name: "dante", avatar: "🧑🏿", stack: 1000),
            Player(id: "merry", name: "merry_ti", avatar: "🧑🏾", stack: 266),
            Player(id: "jsven", name: "jsven", avatar: "🧑🏻", stack: 138),
            Player(id: "great", name: "great_e", avatar: "🧑🏽", stack: 1552),
            Player(id: "verbice", name: "verbice", avatar: "🐱", stack: 408),
        ]
    }

    static func sixPlayers() -> [Player] {
        let names = ["dante", "merry_ti", "jsven", "great_e", "verbice", "guest6"]
        let avatars = ["🧑🏿", "🧑🏾", "🧑🏻", "🧑🏽", "🐱", "🦊"]
        return names.indices.map {
            Player(id: "p\($0)", name: names[$0], avatar: avatars[$0], stack: 1000)
        }
    }
}
