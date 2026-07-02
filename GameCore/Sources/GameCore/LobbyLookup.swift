public extension Lobby {
    func seat(id: String) -> LobbySeat? {
        seats.first { $0.id == id }
    }

    func isReady(id: String) -> Bool {
        seat(id: id)?.isReady ?? false
    }

    func contains(_ id: String) -> Bool {
        seat(id: id) != nil
    }
}

extension Lobby {
    func seatIndex(id: String) -> Int? {
        seats.firstIndex { $0.id == id }
    }
}
