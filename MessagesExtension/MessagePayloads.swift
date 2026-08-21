import Foundation
import Messages
import UIKit
import GameCore

enum SelectedTableMessage {
    case none
    case invalidPayload
    case message(TableMessage)
}

enum MessagePayloads {
    private static let payloadKey = "g"
    private static let transportScheme = "data"
    private static let transportPath = ",river"

    static func tableMessage(from message: MSMessage?) -> SelectedTableMessage {
        guard let url = message?.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return .none
        }
        let isCurrentTransport = components.scheme == transportScheme
            && components.path == transportPath
        let isLegacyTransport = components.scheme == "holdem" && components.host == "table"
        guard isCurrentTransport || isLegacyTransport else { return .none }
        guard let items = components.queryItems else { return .invalidPayload }
        let payloads = items.filter { $0.name == payloadKey }
        guard payloads.count == 1, let payload = payloads[0].value else {
            return .invalidPayload
        }

        do {
            return .message(try GamePayload.decodeMessage(from: payload))
        } catch {
            return .invalidPayload
        }
    }

    static func revision(from message: MSMessage?) -> TableRevision? {
        guard case .message(let table) = tableMessage(from: message) else { return nil }
        return table.revision
    }

    static func makeMessage(for message: TableMessage,
                            replacing sourceMessage: MSMessage?) throws -> MSMessage {
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
            URLQueryItem(name: payloadKey, value: try GamePayload.encode(message))
        ]
        guard let url = components.url else {
            throw EncodingError.invalidValue(
                message, .init(codingPath: [], debugDescription: "Could not build message URL"))
        }
        messageView.url = url

        return messageView
    }
}
