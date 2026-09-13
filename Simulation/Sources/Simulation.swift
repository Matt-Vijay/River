import Foundation
import Observation
import Poker
import RiverUI

@MainActor @Observable final class SimulatedPlayer: Identifiable {
    let index: Int
    let id: String
    let name: String
    let defaults: UserDefaults
    let suite: String
    var history: TableHistory
    var session: RiverSession
    var online = true
    var inbox: [LocalSimulation.Packet] = []

    init(index: Int, name: String, run: String) {
        self.index = index
        self.id = "player-\(index)"
        self.name = name
        suite = "river.simulation.\(run).\(index)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set(["name": name, "avatar": Characters.all[index]], forKey: "holdem.profile")
        history = TableHistory(defaults: defaults)
        session = RiverSession(isLocal: false, defaults: defaults)
        session.localID = id
    }

    var latest: TableMessage? { session.table.flatMap { history.latest($0.id) } }
    var alias: String { "device-\(index)" }

    func remember(_ packet: LocalSimulation.Packet, update: TableMessage) throws {
        for (index, cached) in inbox.enumerated() {
            let prior = try cached.decode()
            if prior.table.id == update.table.id {
                if update.isNewer(than: prior) {
                    inbox.remove(at: index)
                    inbox.append(packet)
                }
                return
            }
        }
        inbox.append(packet)
        if inbox.count > 32 { inbox.removeFirst() }
    }
}

/// The transport carries only URL strings. Every recipient decodes and accepts
/// them against its own persistent history, just as the Messages host does.
@MainActor @Observable final class LocalSimulation {
    struct Packet: Codable {
        let sender: Int
        let url: String

        func decode() throws -> TableMessage {
            guard let url = URL(string: url) else { throw TableError.invalidState }
            return try TableMessage(url: url)
        }
    }
    struct Delivery {
        let recipient: Int
        let packet: Packet
    }
    struct Event: Codable {
        let number: Int
        let description: String
        let revisions: [Int?]
        let fingerprints: [String?]
        let queued: Int
    }
    struct Report: Codable {
        let seed: UInt64
        let checks: [String]
        let hands: Int
        let packets: [Packet]
        let events: [Event]
        let finalTables: [Table]
    }
    struct Failure: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    let players: [SimulatedPlayer]
    let seed: UInt64
    private let traceLimit: Int
    var queue: [Delivery] = []
    var packets: [Packet] = []
    var events: [Event] = []
    var checks: [String] = []
    var playing = false
    var selected = 0
    var clock: Date?
    private var turnCount = 0

    init(seed: UInt64 = 42, clock: Date? = nil, run: String = UUID().uuidString, traceLimit: Int = .max) {
        self.seed = seed
        self.clock = clock
        self.traceLimit = max(1, traceLimit)
        players = ["Morgan", "Sam", "Taylor", "Jordan", "Casey"].enumerated().map {
            SimulatedPlayer(index: $0.offset, name: $0.element, run: run)
        }
        for player in players { connect(player) }
    }

    var now: Date { clock ?? Date() }
    var selectedPlayer: SimulatedPlayer { players[selected] }
    var synchronized: Bool {
        let prints = players.compactMap { $0.latest?.fingerprint }
        return prints.count == players.count && Set(prints).count == 1
    }

    func cleanup() {
        playing = false
        for player in players {
            player.session.onEvent = nil
            player.defaults.removePersistentDomain(forName: player.suite)
        }
    }

    private func connect(_ player: SimulatedPlayer) {
        player.session.onEvent = { [weak self, weak player] event in
            guard let self, let player else { return }
            attempt {
                switch event {
                case .newTable: try create(by: player.index)
                case .action(let action): try send(action, from: player.index)
                case .profileSaved: try open(player.index)
                case .close: player.session.surface = .invitation
                case .expand: break
                }
            }
        }
    }

    func attempt(_ operation: () throws -> Void) {
        do { try operation() }
        catch {
            playing = false
            selectedPlayer.session.error = error.localizedDescription
            record("ERROR: \(error.localizedDescription)")
        }
    }

    func create(by index: Int) throws {
        let table = Table(id: "local-\(seed)-\(events.last?.number ?? 0)")
        try send(.join(players[index].session.profile!), from: index, on: table)
    }

    func send(_ action: Action, from index: Int, on initial: Table? = nil) throws {
        let player = players[index]
        guard player.online else {
            throw URLError(.notConnectedToInternet,
                           userInfo: [NSLocalizedDescriptionKey: "\(player.name) is offline. Reconnect before sending."])
        }
        guard let table = initial ?? player.session.table else { throw TableError.invalidState }
        if let latest = player.history.latest(table.id), latest.table != table { throw TableError.stale }
        let message = try TableMessage(recording: action, on: table, actor: player.id, at: now)
        let packet = Packet(sender: index, url: try message.url().absoluteString)
        // The sender also accepts a decoded wire message; it does not publish a shared Table.
        let accepted = try accept(packet.decode(), from: packet.sender, at: index)
        player.session.surface = .table(accepted.table)
        try player.remember(packet, update: message)
        packets.append(packet)
        if packets.count > traceLimit { packets.removeFirst(packets.count - traceLimit) }
        for recipient in players.indices where recipient != index {
            queue.append(Delivery(recipient: recipient, packet: packet))
        }
        record("\(player.name): \(actionName(action))")
    }

    private func accept(_ message: TableMessage, from senderIndex: Int, at index: Int, senderOverride: String? = nil) throws -> TableMessage {
        let player = players[index]
        let sender = senderOverride ?? (senderIndex == index ? player.id : "\(player.alias)-sender-\(senderIndex)")
        return try player.history.accept(message, sender: sender, localID: player.id)
    }

    func receive(_ packet: Packet, at index: Int, senderOverride: String? = nil) throws {
        let player = players[index]
        let update = try packet.decode()
        if player.session.table?.id == update.table.id || player.history.latest(update.table.id) != nil {
            let latest = try accept(update, from: packet.sender, at: index, senderOverride: senderOverride)
            if player.session.table?.id == update.table.id { player.session.surface = .table(latest.table) }
        }
        try player.remember(packet, update: update)
        record("Delivered \(players[packet.sender].name) -> \(player.name)")
    }

    func deliverAll(reversed: Bool = false) throws {
        let ready = queue.filter { players[$0.recipient].online }
        queue.removeAll { players[$0.recipient].online }
        for delivery in reversed ? ready.reversed() : ready {
            try receive(delivery.packet, at: delivery.recipient)
        }
    }

    func open(_ index: Int, packet: Packet? = nil) throws {
        let player = players[index]
        // Only newer revisions move a table's bubble; stale replays leave this choice alone.
        guard let packet = packet ?? player.inbox.last else { return }
        let latest = try accept(packet.decode(), from: packet.sender, at: index)
        player.session.surface = .table(latest.table)
        record("\(player.name) opened table")
        if latest.table.canJoin(player.id) { try send(.join(player.session.profile!), from: index) }
    }

    func restart(_ index: Int) throws {
        let player = players[index]
        player.history = TableHistory(defaults: player.defaults)
        player.session = RiverSession(isLocal: false, defaults: player.defaults)
        player.session.localID = player.id
        connect(player)
        try open(index)
        record("\(player.name) restarted from disk")
    }

    func advance() throws {
        if let index = queue.firstIndex(where: { players[$0.recipient].online }) {
            let delivery = queue.remove(at: index)
            try receive(delivery.packet, at: delivery.recipient)
        } else if packets.isEmpty {
            try create(by: 0)
        } else if Set(players.filter { $0.online }.compactMap { $0.session.table?.id }).count > 1 {
            throw Failure(message: "Online players are viewing different tables. Open the same table for each player before resuming.")
        } else if let player = players.first(where: { $0.online && $0.session.table == nil }) {
            try open(player.index)
        } else {
            try playTurn()
        }
    }

    func playTurn(allIn: Bool = false) throws {
        guard let observer = players.first(where: { $0.online && $0.session.table != nil }),
              let table = observer.session.table else { return }
        if table.isFinished { playing = false; return }
        if table.canDeal {
            guard let dealer = players.first(where: { $0.online && table.seat($0.id)?.isEligible == true }) else { return }
            try send(.deal(seed: seed + UInt64(table.hand?.number ?? 0)), from: dealer.index)
        } else if table.hand?.remaining(at: now) == 0 {
            guard let resolver = players.first(where: { $0.online && table.seat($0.id)?.hasLeft == false }) else { return }
            try send(.timeout, from: resolver.index)
        } else if let actor = players.first(where: { $0.id == table.hand?.turn }), let own = actor.session.table {
            guard actor.online else { return }
            guard let legal = own.legalBet(for: actor.id, at: now) else { throw TableError.notYourTurn }
            turnCount += 1
            let bet: Bet
            if let bounds = legal.raise, allIn || turnCount % 5 == 0 {
                bet = .raiseTo(allIn ? bounds.upperBound : bounds.lowerBound)
            } else if !allIn, turnCount % 11 == 0, (own.hand?.contenders.count ?? 0) > 2 {
                bet = .fold
            } else { bet = legal.canCheck ? .check : .call }
            try send(.bet(bet), from: actor.index)
        }
    }

    func record(_ description: String) {
        let latest = players.map(\.latest)
        events.append(Event(number: (events.last?.number ?? 0) + 1, description: description,
            revisions: latest.map { $0?.table.version },
            fingerprints: latest.map { $0?.fingerprint }, queued: queue.count))
        if events.count > traceLimit { events.removeFirst(events.count - traceLimit) }
    }

    func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failure(message: message) }
    }

    func verifyAgreement(chips: Int = 5_000) throws {
        try require(synchronized, "Clients disagree after delivery drained")
        for player in players {
            guard let table = player.session.table else { throw TableError.invalidState }
            _ = try table.validated()
            try require(table.chipTotal == chips, "Chip conservation failed on \(player.name)")
            try require(player.session.viewerID == player.id, "Wrong private-hand identity")
        }
    }

    private func actionName(_ action: Action) -> String {
        switch action {
        case .join: "Join"
        case .leave: "Leave"
        case .deal: "Deal"
        case .bet(.raiseTo(let amount)): "Raise to \(amount)"
        case .bet(let bet): bet.name
        case .timeout: "Resolve expired turn"
        }
    }
}
