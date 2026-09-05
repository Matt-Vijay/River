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
        guard !string.isEmpty, string.utf8.count % 4 != 1,
              string.utf8.allSatisfy({ byte in
                  (48...57).contains(byte) || (65...90).contains(byte)
                      || (97...122).contains(byte) || byte == 45 || byte == 95
              }) else { return nil }
        var padded = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = padded.count % 4
        if remainder > 0 { padded += String(repeating: "=", count: 4 - remainder) }
        self.init(base64Encoded: padded)
        guard base64URLEncodedString() == string else { return nil }
    }
}

extension GamePayload {
    static let legacyTableIDKey = CodingUserInfoKey(
        rawValue: "com.dewylabs.river.legacyTableID"
    )!
    static let integrityPrevalidatedKey = CodingUserInfoKey(
        rawValue: "com.dewylabs.river.integrityPrevalidated"
    )!
    static let wireVersionKey = CodingUserInfoKey(
        rawValue: "com.dewylabs.river.wireVersion"
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

    public static func encode(_ message: TableMessage) throws -> String {
        let data = try encoder.encode(message)
        guard data.count <= maximumDecodedPayloadLength else {
            throw EncodingError.invalidValue(
                message,
                .init(codingPath: [], debugDescription: "Decoded table payload exceeds limit")
            )
        }
        let compressed = try (data as NSData).compressed(using: .lzfse) as Data
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
        guard !string.isEmpty else {
            throw decodingError("Table payload is empty")
        }
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
        let root = try validateJSONShape(data)
        try validateIntegrity(in: root)
        let decoder = decoder
        decoder.userInfo[legacyTableIDKey] = data
        decoder.userInfo[integrityPrevalidatedKey] = true
        decoder.userInfo[wireVersionKey] = root["wireVersion"] as? Int ?? 0
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
        guard count > 0 else {
            throw decodingError("Invalid compressed table payload")
        }
        guard count <= maximumDecodedPayloadLength else {
            throw decodingError("Decoded table payload exceeds limit")
        }
        decoded.count = count
        return decoded
    }

    private static func decodingError(_ description: String) -> DecodingError {
        .dataCorrupted(.init(codingPath: [], debugDescription: description))
    }

    private static func validateJSONShape(_ data: Data) throws -> [String: Any] {
        var scanner = JSONShapeScanner(data)
        try scanner.validate()
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw decodingError("Table payload root must be an object")
        }
        return object
    }

    /// JSONSerialization intentionally accepts repeated object keys. Walk the
    /// already size-bounded UTF-8 source as tokens so no object can smuggle an
    /// alternate value past the canonical integrity and Codable passes.
    private struct JSONShapeScanner {
        private let bytes: [UInt8]
        private var index = 0
        private var nodeCount = 0

        init(_ data: Data) {
            bytes = Array(data)
        }

        mutating func validate() throws {
            skipWhitespace()
            try scanValue(depth: 0)
            skipWhitespace()
            guard index == bytes.count else { throw invalidJSON() }
        }

        private mutating func scanValue(depth: Int) throws {
            nodeCount += 1
            guard nodeCount <= 512, depth <= 12 else {
                throw GamePayload.decodingError("Table payload shape exceeds limits")
            }
            skipWhitespace()
            guard let byte = current else { throw invalidJSON() }
            switch byte {
            case 0x7B: try scanObject(depth: depth) // {
            case 0x5B: try scanArray(depth: depth)  // [
            case 0x22: _ = try scanString()        // "
            default: try scanScalar()
            }
        }

        private mutating func scanObject(depth: Int) throws {
            index += 1
            skipWhitespace()
            if consume(0x7D) { return } // }

            var keys: Set<String> = []
            while true {
                skipWhitespace()
                guard current == 0x22 else { throw invalidJSON() }
                let key = try scanString(maximumBytes: 64)
                guard !key.isEmpty else {
                    throw GamePayload.decodingError("Table field name is empty")
                }
                guard keys.insert(key).inserted else {
                    throw GamePayload.decodingError("Duplicate JSON object field")
                }
                guard keys.count <= 32 else {
                    throw GamePayload.decodingError("Table object has too many fields")
                }

                skipWhitespace()
                guard consume(0x3A) else { throw invalidJSON() } // :
                try scanValue(depth: depth + 1)
                skipWhitespace()
                if consume(0x7D) { return } // }
                guard consume(0x2C) else { throw invalidJSON() } // ,
            }
        }

        private mutating func scanArray(depth: Int) throws {
            index += 1
            skipWhitespace()
            if consume(0x5D) { return } // ]

            var count = 0
            while true {
                count += 1
                guard count <= 64 else {
                    throw GamePayload.decodingError("Table array exceeds limits")
                }
                try scanValue(depth: depth + 1)
                skipWhitespace()
                if consume(0x5D) { return } // ]
                guard consume(0x2C) else { throw invalidJSON() } // ,
            }
        }

        private mutating func scanString(maximumBytes: Int = 4_096) throws -> String {
            let start = index
            guard consume(0x22) else { throw invalidJSON() }
            while let byte = current {
                index += 1
                if byte == 0x22 {
                    let value = try JSONDecoder().decode(String.self, from: Data(bytes[start..<index]))
                    guard value.utf8.count <= maximumBytes else {
                        throw GamePayload.decodingError("Table string exceeds limits")
                    }
                    return value
                }
                if byte == 0x5C { // escaped byte; Foundation validates the escape syntax next
                    guard current != nil else { throw invalidJSON() }
                    index += 1
                }
            }
            throw invalidJSON()
        }

        private mutating func scanScalar() throws {
            let start = index
            while let byte = current,
                  byte != 0x2C, byte != 0x5D, byte != 0x7D,
                  !Self.isWhitespace(byte) {
                index += 1
            }
            guard index > start else { throw invalidJSON() }
        }

        private var current: UInt8? {
            index < bytes.count ? bytes[index] : nil
        }

        private mutating func consume(_ byte: UInt8) -> Bool {
            guard current == byte else { return false }
            index += 1
            return true
        }

        private mutating func skipWhitespace() {
            while let byte = current, Self.isWhitespace(byte) { index += 1 }
        }

        private static func isWhitespace(_ byte: UInt8) -> Bool {
            byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
        }

        private func invalidJSON() -> DecodingError {
            GamePayload.decodingError("Table payload is not valid JSON")
        }
    }

    static func stateFingerprint(for message: TableMessage) -> String {
        guard let data = try? canonicalStateData(for: message) else { return "" }
        return digestIdentifier(for: data, byteCount: 16)
    }

    static func integrityDigest(for message: TableMessage) throws -> String {
        digestIdentifier(for: try canonicalStateData(for: message), byteCount: 32)
    }

    static func integrityMatches(_ supplied: String, message: TableMessage) -> Bool {
        guard supplied.utf8.count == 64,
              let expected = try? integrityDigest(for: message) else { return false }
        return zip(supplied.utf8, expected.utf8).reduce(UInt8(0)) {
            $0 | ($1.0 ^ $1.1)
        } == 0
    }

    private static func canonicalStateData(for message: TableMessage) throws -> Data {
        let kind: String
        let encodedState: Data
        switch message {
        case .lobby(let lobby):
            kind = "lobby"
            encodedState = try encoder.encode(lobby)
        case .game(let game):
            kind = "game"
            encodedState = try encoder.encode(game)
        }
        let stateObject = try JSONSerialization.jsonObject(with: encodedState)
        let state = try JSONSerialization.data(withJSONObject: stateObject, options: [.sortedKeys])

        return framedStateData(kind: kind, state: state)
    }

    private static func framedStateData(kind: String, state: Data) -> Data {
        var framed = Data("river-table-state-v1\u{0}".utf8)
        framed.append(contentsOf: kind.utf8)
        framed.append(0)
        framed.append(state)
        return framed
    }

    private static func validateIntegrity(in root: [String: Any]) throws {
        let wireVersion = root["wireVersion"] as? Int ?? 0
        guard wireVersion == 2 else { return }
        let payloads = ["lobby", "game"].compactMap { kind -> (String, Any)? in
            guard let wrapper = root[kind] as? [String: Any], let value = wrapper["_0"] else {
                return nil
            }
            return (kind, value)
        }
        guard payloads.count == 1,
              let supplied = root["integrity"] as? String else {
            throw decodingError("Table message integrity metadata is missing")
        }
        let state = try JSONSerialization.data(
            withJSONObject: payloads[0].1, options: [.sortedKeys])
        let expected = digestIdentifier(
            for: framedStateData(kind: payloads[0].0, state: state), byteCount: 32)
        guard supplied.utf8.count == expected.utf8.count else {
            throw decodingError("Table message integrity check failed")
        }
        let mismatch = zip(supplied.utf8, expected.utf8).reduce(UInt8(0)) {
            $0 | ($1.0 ^ $1.1)
        }
        guard mismatch == 0 else {
            throw decodingError("Table message integrity check failed")
        }
    }

    private static func digestIdentifier(for data: Data, byteCount: Int = 16) -> String {
        SHA256.hash(data: data).prefix(byteCount)
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
