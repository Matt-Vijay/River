import Foundation
import Messages
import UIKit
import GameCore

enum SelectedTableMessage {
    case none
    case invalidPayload
    /// Receipt-less transports remain displayable for migration, but can never
    /// authorize a table mutation.
    case unverified(TableMessage)
    case message(TableMessage)

    var decodedMessage: TableMessage? {
        switch self {
        case .unverified(let message), .message(let message): message
        case .none, .invalidPayload: nil
        }
    }
}

/// A decoded snapshot of one message. Receive/select callbacks establish trust;
/// rendering and send completion use the same immutable table and revision.
@MainActor
struct MessageSource {
    let message: MSMessage
    let content: SelectedTableMessage
    let revision: TableRevision?

    init(receiving message: MSMessage, localID: String, history: TableHistory,
         predecessor: TableMessage? = nil) {
        self.message = message
        content = Self.decode(message, localID: localID, history: history, predecessor: predecessor)
        revision = content.decodedMessage?.revision
    }

    init(sending table: TableMessage, receipt: TableMutationReceipt,
         replacing source: MSMessage?) throws {
        message = try Self.makeMessage(for: table, receipt: receipt, replacing: source)
        content = .message(table)
        revision = receipt.resultRevision
    }

    func supersedes(_ baseline: MessageSource) -> Bool {
        guard case .message = content, case .message = baseline.content,
              let revision, let previous = baseline.revision else { return false }
        return revision.tableID != previous.tableID || previous.isOlder(than: revision)
    }

    func shouldDisplay(replacing current: MessageSource?) -> Bool {
        guard case .message = content, let revision else { return false }
        guard let current else { return true }
        if let previous = current.revision {
            return revision.isSameOrNewer(than: previous)
        }
        return message.session != nil && message.session == current.message.session
    }

    private static let payloadKey = "g"
    private static let receiptKey = "r"
    private static let transportScheme = "data"
    private static let transportPath = ",river"
    /// Messages documents a 5,000-character URL ceiling. Count UTF-8 bytes as
    /// the stricter bound because every URL this transport emits is ASCII.
    private static let maximumURLLength = 5_000

    private static func decode(_ message: MSMessage, localID: String, history: TableHistory,
                               predecessor: TableMessage?) -> SelectedTableMessage {
        guard let url = message.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return .none
        }
        let isCurrentTransport = components.scheme == transportScheme
            && components.host == nil
            && components.path == transportPath
        let isLegacyTransport = components.scheme == "holdem"
            && components.host == "table"
            && components.path.isEmpty
        guard isCurrentTransport || isLegacyTransport else { return .none }
        guard url.absoluteString.utf8.count <= maximumURLLength,
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.fragment == nil,
              let items = components.queryItems,
              !items.isEmpty,
              items.allSatisfy({ $0.value != nil }),
              Set(items.map(\.name)).count == items.count else {
            return .invalidPayload
        }

        let names = Set(items.map(\.name))
        guard names == [payloadKey] || (isCurrentTransport && names == [payloadKey, receiptKey]),
              let payload = items.first(where: { $0.name == payloadKey })?.value else {
            return .invalidPayload
        }

        guard let table = try? GamePayload.decodeMessage(from: payload) else { return .invalidPayload }

        // Both the old holdem URL and the receipt-less current URL predate
        // participant binding. They are intentionally read-only.
        guard isCurrentTransport, names.contains(receiptKey),
              let encodedReceipt = items.first(where: { $0.name == receiptKey })?.value,
              let receipt = try? TableMutationReceipt.decode(from: encodedReceipt),
              receipt.matchesResult(table) else {
            return isLegacyTransport || names == [payloadKey]
                ? .unverified(table)
                : .invalidPayload
        }

        guard let actor = TableActor(receipt.actorID) else { return .invalidPayload }

        // A locally held state is only a replay predecessor when its full
        // revision (including the state fingerprint branch) matches the claim.
        // Unrelated or skipped states do not make an otherwise bound receipt
        // fail merely because they happen to be on screen.
        if let predecessor, predecessor.revision == receipt.parentRevision {
            guard receipt.replay(
                predecessor: predecessor,
                authenticatedActor: actor
            ) != nil else {
                return .invalidPayload
            }
        }

        // Learn the device-local sender alias only after the payload and any
        // available replay have passed. Never compare UUIDs across devices.
        guard history.bind(actor, senderID: message.senderParticipantIdentifier.uuidString,
                           localID: localID, result: receipt.resultRevision) else {
            return .invalidPayload
        }
        return .message(table)
    }

    private static func makeMessage(for message: TableMessage,
                            receipt: TableMutationReceipt,
                            replacing sourceMessage: MSMessage?) throws -> MSMessage {
        guard receipt.matchesResult(message) else {
            throw EncodingError.invalidValue(
                receipt,
                .init(codingPath: [],
                      debugDescription: "Mutation receipt does not match table result"))
        }
        let session = sourceMessage?.session ?? MSSession()
        let messageView = MSMessage(session: session)
        let summary = GamePayload.summary(for: message)
        let layout = MSMessageTemplateLayout()

        layout.image = UIImage(named: "TableMessage")
        layout.caption = "River Hold’em"
        layout.trailingCaption = "Open table"
        switch message {
        case .lobby(let lobby):
            layout.subcaption = lobby.isFull
                ? "Table full"
                : "\(lobby.seats.count)/\(lobby.maxPlayers) seated"
            messageView.summaryText = lobby.isFull
                ? "River Texas Hold’em. Table full. Open table."
                : "River Texas Hold’em. \(lobby.seats.count) of \(lobby.maxPlayers) seated. Open table."
        case .game:
            layout.subcaption = summary
            messageView.summaryText = "River Texas Hold’em. \(summary). Open table."
        }
        messageView.layout = layout
        messageView.accessibilityLabel = messageView.summaryText
        var components = URLComponents()
        components.scheme = transportScheme
        components.path = transportPath
        components.queryItems = [
            URLQueryItem(name: payloadKey, value: try GamePayload.encode(message)),
            URLQueryItem(name: receiptKey, value: try receipt.encodedString())
        ]
        guard let url = components.url,
              url.absoluteString.utf8.count <= maximumURLLength else {
            throw EncodingError.invalidValue(
                message,
                .init(codingPath: [],
                      debugDescription: "Could not build message URL within transport limit"))
        }
        messageView.url = url

        return messageView
    }
}

final class TableHistory {
    private struct Record: Codable, Equatable {
        let tableID: String
        var revision: TableRevision?
        var participants = TableParticipants()
    }

    private static let limit = 64
    private let defaults: UserDefaults
    private let key = "RiverTableHistory.v1"
    private let legacyKey = "HoldemLatestTableRevisions.v1"
    private lazy var records = loadRecords()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func latest(for tableID: String) -> TableRevision? {
        records.first { $0.tableID == tableID }?.revision
    }

    func bind(_ actor: TableActor, senderID: String, localID: String, result: TableRevision) -> Bool {
        var record = records.first { $0.tableID == result.tableID } ?? Record(tableID: result.tableID)
        // Messages can re-alias our own sent bubble. Recognize only an exact
        // already-known result, never a new state claiming the local seat.
        if actor.id == localID, record.revision == result { return true }
        guard record.participants.bind(actor, senderID: senderID, localID: localID) else {
            return false
        }
        save(record)
        return true
    }

    @discardableResult
    func observe(_ revision: TableRevision) -> Bool {
        var record = records.first { $0.tableID == revision.tableID }
            ?? Record(tableID: revision.tableID)
        if let latest = record.revision {
            guard revision.isSameOrNewer(than: latest) else { return false }
        }
        record.revision = revision
        save(record)
        return true
    }

    private func save(_ record: Record) {
        if let index = records.firstIndex(where: { $0.tableID == record.tableID }) {
            guard records[index] != record else { return }
            records.remove(at: index)
        }
        records.append(record)
        // Messages we have not opened must not evict remembered table revisions.
        records = Array(records.filter { $0.revision != nil }.suffix(Self.limit))
            + Array(records.filter { $0.revision == nil }.suffix(Self.limit))
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: key)
            defaults.removeObject(forKey: legacyKey)
        }
    }

    private func loadRecords() -> [Record] {
        if let data = defaults.data(forKey: key),
           let records = try? JSONDecoder().decode([Record].self, from: data) {
            return Array(records.filter { $0.revision != nil }.suffix(Self.limit))
                + Array(records.filter { $0.revision == nil }.suffix(Self.limit))
        }
        let legacy = defaults.data(forKey: legacyKey)
            .flatMap { try? JSONDecoder().decode([TableRevision].self, from: $0) } ?? []
        var normalized: [Record] = []
        for revision in legacy {
            if let index = normalized.firstIndex(where: { $0.tableID == revision.tableID }) {
                if let latest = normalized[index].revision,
                   !revision.isSameOrNewer(than: latest) { continue }
                normalized.remove(at: index)
            }
            normalized.append(Record(tableID: revision.tableID, revision: revision))
        }
        return Array(normalized.suffix(Self.limit))
    }
}
