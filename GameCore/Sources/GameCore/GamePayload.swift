import Compression
import CryptoKit
import Foundation

/// Packs game data into compact, URL-safe forms for iMessage payloads.
public enum GamePayload {
    /// Leaves room for URL syntax under Messages' 5,000-character limit.
    static let maximumEncodedPayloadLength = 4_900
    static let maximumDecodedPayloadLength = 16 * 1_024
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var string = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = string.count % 4
        if remainder > 0 { string += String(repeating: "=", count: 4 - remainder) }
        self.init(base64Encoded: string)
    }
}

extension GamePayload {
    static let legacyTableIDKey = CodingUserInfoKey(
        rawValue: "com.dewylabs.river.legacyTableID"
    )!

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }

    static func legacyTableID(from decoder: Decoder) throws -> String {
        guard let data = decoder.userInfo[legacyTableIDKey] as? Data else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Missing table identity"
                )
            )
        }
        let canonicalData = try JSONSerialization.data(
            withJSONObject: try JSONSerialization.jsonObject(with: data),
            options: [.sortedKeys]
        )
        return "legacy-v1-\(digestIdentifier(for: canonicalData))"
    }

    static func conflictKey(for message: TableMessage) -> String {
        guard let data = try? encoder.encode(message) else { return "" }
        return digestIdentifier(for: data)
    }

    public static func encode(_ message: TableMessage) throws -> String {
        let compressed = try (encoder.encode(message) as NSData).compressed(using: .lzfse) as Data
        let encoded = "z" + compressed.base64URLEncodedString()
        guard encoded.utf8.count <= maximumEncodedPayloadLength else {
            throw EncodingError.invalidValue(
                message,
                .init(codingPath: [], debugDescription: "Table payload exceeds transport limit")
            )
        }
        return encoded
    }

    public static func decodeMessage(from string: String) throws -> TableMessage {
        guard string.utf8.count <= maximumEncodedPayloadLength else {
            throw decodingError("Table payload exceeds transport limit")
        }
        let isCompressed = string.first == "z"
        let encodedData = isCompressed ? String(string.dropFirst()) : string
        guard let wireData = Data(base64URLEncoded: encodedData) else {
            throw decodingError("Not valid base64url")
        }
        let data = try isCompressed
            ? decompressedPayload(wireData)
            : wireData
        guard data.count <= maximumDecodedPayloadLength else {
            throw decodingError("Decoded table payload exceeds limit")
        }
        let decoder = decoder
        decoder.userInfo[legacyTableIDKey] = data
        return try decoder.decode(TableMessage.self, from: data)
    }

    private static func decompressedPayload(_ data: Data) throws -> Data {
        let capacity = maximumDecodedPayloadLength + 1
        var decoded = Data(count: capacity)
        let count = decoded.withUnsafeMutableBytes { destination in
            data.withUnsafeBytes { source in
                guard let destination = destination.bindMemory(to: UInt8.self).baseAddress,
                      let source = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(
                    destination, capacity, source, data.count, nil, COMPRESSION_LZFSE)
            }
        }
        guard count > 0, count <= maximumDecodedPayloadLength else {
            throw decodingError("Invalid or oversized compressed table payload")
        }
        decoded.count = count
        return decoded
    }

    private static func decodingError(_ description: String) -> DecodingError {
        .dataCorrupted(.init(codingPath: [], debugDescription: description))
    }

    private static func digestIdentifier(for data: Data) -> String {
        SHA256.hash(data: data).prefix(16)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

public extension GamePayload {
    static func summary(for message: TableMessage) -> String {
        switch message {
        case .lobby(let lobby):
            return "Lobby · \(lobby.seats.count)/\(lobby.maxPlayers) seated"
        case .game(let state):
            return summary(for: state)
        }
    }

    /// Caption shown on the collapsed message bubble in the transcript.
    static func summary(for state: GameState) -> String {
        if let winner = state.overallWinner {
            return "\(SummaryNameText.string(winner.name)) wins the game"
        }
        if let results = state.results, !results.isEmpty {
            return state.resultSummaryText(results: results)
        }
        return state.liveSummaryText
    }
}

private extension GameState {
    var liveSummaryText: String {
        let prefix = "\(street.summaryName) · Pot \(ChipText.string(displayPot))"
        guard let player = currentPlayer else { return prefix }
        return "\(prefix) · \(SummaryNameText.string(player.name)) to act"
    }

    func resultSummaryText(results: [HandResult]) -> String {
        if results.count > 1 {
            let names = results.compactMap {
                player(id: $0.playerID).map { SummaryNameText.string($0.name) }
            }
            if names.count > 1 {
                let amounts = Set(results.map(\.amountWon))
                if amounts.count == 1, let amount = amounts.first {
                    return "\(Self.joinedNames(names)) won \(ChipText.string(amount)) each"
                }
                return "\(Self.joinedNames(names)) won pots"
            }
        }

        guard let top = results.max(by: { $0.amountWon < $1.amountWon }),
              let topPlayer = player(id: top.playerID) else {
            return "Hand #\(handNumber) complete"
        }
        let winner = "\(SummaryNameText.string(topPlayer.name)) won \(ChipText.string(top.amountWon))"
        return top.handName.map { "\(winner) with a \($0)" } ?? winner
    }

    static func joinedNames(_ names: [String]) -> String {
        guard names.count > 1 else { return names.first ?? "" }
        if names.count == 2 { return "\(names[0]) and \(names[1])" }
        return "\(names.dropLast().joined(separator: ", ")), and \(names.last ?? "")"
    }
}

private extension Street {
    var summaryName: String {
        switch self {
        case .preflop: "Pre-flop"
        case .flop: "Flop"
        case .turn: "Turn"
        case .river: "River"
        case .showdown: "Showdown"
        }
    }
}

private enum SummaryNameText {
    static func string(_ name: String) -> String {
        let normalized = ProfileText.name(name)
        return normalized.count <= 18 ? normalized : String(normalized.prefix(17)) + "…"
    }
}
