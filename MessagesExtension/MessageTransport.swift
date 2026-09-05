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

enum MessagePayloads {
    private static let payloadKey = "g"
    private static let receiptKey = "r"
    private static let transportScheme = "data"
    private static let transportPath = ",river"
    /// Messages documents a 5,000-character URL ceiling. Count UTF-8 bytes as
    /// the stricter bound because every URL this transport emits is ASCII.
    private static let maximumURLLength = 5_000

    /// A nil `senderParticipantIdentifier` never authenticates a received
    /// message. The explicit optimistic identity is only for an `MSMessage`
    /// object the controller itself just constructed locally.
    static func tableMessage(
        from message: MSMessage?,
        authenticatingOptimisticLocalParticipant optimisticLocalParticipant: UUID? = nil,
        predecessor: TableMessage? = nil
    ) -> SelectedTableMessage {
        guard let url = message?.url,
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

        let authenticatedParticipant: UUID
        if let sender = message?.senderParticipantIdentifier {
            if let optimisticLocalParticipant, sender != optimisticLocalParticipant {
                return .invalidPayload
            }
            authenticatedParticipant = sender
        } else if let optimisticLocalParticipant {
            authenticatedParticipant = optimisticLocalParticipant
        } else {
            return .invalidPayload
        }
        guard receipt.actorID == authenticatedParticipant.uuidString,
              let actor = TableActor(receipt.actorID) else {
            return .invalidPayload
        }

        // A locally held state is only a replay predecessor when its full
        // revision (including the state fingerprint branch) matches the claim.
        // Unrelated or skipped states do not make an otherwise bound receipt
        // fail merely because they happen to be on screen.
        if let predecessor, predecessor.revision == receipt.parentRevision {
            guard receipt.replay(
                predecessor: predecessor,
                authenticatedActor: actor
            ) == table else {
                return .invalidPayload
            }
        }

        return .message(table)
    }

    static func makeMessage(for message: TableMessage,
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

final class LatestRevisionStore {
    private static let limit = 64
    private let defaults: UserDefaults
    private let key = "HoldemLatestTableRevisions.v1"
    private lazy var revisions = loadRevisions()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func latest(for tableID: String) -> TableRevision? {
        revisions.first { $0.tableID == tableID }
    }

    @discardableResult
    func observe(_ revision: TableRevision) -> Bool {
        if let index = revisions.firstIndex(where: { $0.tableID == revision.tableID }) {
            let latest = revisions[index]
            guard revision.isSameOrNewer(than: latest) else { return false }
            guard revision != latest else { return true }
            revisions.remove(at: index)
        }
        revisions.append(revision)
        revisions = Array(revisions.suffix(Self.limit))
        if let data = try? JSONEncoder().encode(revisions) {
            defaults.set(data, forKey: key)
        }
        return true
    }

    private func loadRevisions() -> [TableRevision] {
        guard let data = defaults.data(forKey: key),
              let revisions = try? JSONDecoder().decode([TableRevision].self, from: data) else {
            defaults.removeObject(forKey: key)
            return []
        }
        var normalized: [TableRevision] = []
        for revision in revisions {
            if let index = normalized.firstIndex(where: { $0.tableID == revision.tableID }) {
                guard revision.isSameOrNewer(than: normalized[index]) else { continue }
                normalized.remove(at: index)
            }
            normalized.append(revision)
        }
        return Array(normalized.suffix(Self.limit))
    }
}
