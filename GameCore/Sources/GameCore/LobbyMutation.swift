public extension Lobby {
    /// Adds a seat. Repeated joins are idempotent; identity is configured before joining.
    func adding(id: String, name: String, avatar: String) -> Lobby {
        if contains(id) {
            return self
        }
        guard !isFull else { return self }
        var copy = self
        copy.seats.append(LobbySeat(id: id, name: name, avatar: avatar))
        copy.version += 1
        return copy
    }

    /// Removes a seat (a player leaving the lobby).
    func removing(id: String) -> Lobby {
        var copy = self
        let oldCount = copy.seats.count
        copy.seats.removeAll { $0.id == id }
        if copy.seats.count != oldCount { copy.version += 1 }
        return copy
    }

    /// Updates a seat's name / avatar / ready flag.
    func updating(id: String, name: String? = nil, avatar: String? = nil,
                  isReady: Bool? = nil) -> Lobby {
        var copy = self
        copy.updateSeat(id: id, name: name, avatar: avatar, isReady: isReady)
        return copy
    }
}

extension Lobby {
    mutating func updateSeat(id: String, name: String? = nil, avatar: String? = nil,
                             isReady: Bool? = nil) {
        guard let i = seatIndex(id: id) else { return }
        let oldSeat = seats[i]
        seats[i].updateProfile(name: name, avatar: avatar, isReady: isReady)
        if seats[i] != oldSeat { version += 1 }
    }
}
