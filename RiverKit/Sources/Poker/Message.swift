import Compression
import CryptoKit
import Foundation

/// A validated snapshot and the operation that produced it. This is an integrity
/// and replay record, not a cryptographic signature or a claim of sender identity.
public struct TableMessage: Sendable {
    public struct Move: Codable, Equatable, Sendable {
        public let actor: String
        public let action: Action
        public let parent: String
        public let time: Int64
    }

    private struct Body: Codable {
        let format: Int
        let table: Table
        let move: Move
    }

    private struct Envelope: Codable {
        let body: Body
        let checksum: String
    }

    public let table: Table
    public let move: Move
    public let fingerprint: String
    let legacyBranch: String?
    private let legacyURL: URL?
    private static let maximumBytes = 24_576

    public init(recording action: Action, on table: Table, actor: String, at date: Date = Date()) throws {
        let time = date.timeIntervalSince1970 * 1_000
        guard time.isFinite, (0...253_402_300_000_000).contains(time) else { throw TableError.invalidState }
        let milliseconds = Int64(time.rounded(.down))
        let appliedAt = Date(timeIntervalSince1970: Double(milliseconds) / 1_000)
        let next = try table.applying(action, by: actor, at: appliedAt).validated()
        guard next.version > table.version else { throw TableError.illegalBet }
        self.table = next
        move = Move(actor: actor, action: action, parent: try Self.digest(table), time: milliseconds)
        fingerprint = try Self.digest(next)
        legacyURL = nil
        legacyBranch = nil
    }

    public func verifies(after predecessor: Table) -> Bool {
        guard predecessor.id == table.id,
              (try? Self.digest(predecessor)) == move.parent else { return false }
        return (try? predecessor.applying(move.action, by: move.actor,
                    at: Date(timeIntervalSince1970: Double(move.time) / 1_000))) == table
    }

    public func isNewer(than other: TableMessage) -> Bool {
        table.id == other.table.id
            && (legacyURL == nil ? 1 : 0, table.hand == nil ? 0 : 1, table.version, fingerprint)
             > (other.legacyURL == nil ? 1 : 0, other.table.hand == nil ? 0 : 1, other.table.version, other.fingerprint)
    }

    public func url() throws -> URL {
        if let legacyURL { return legacyURL }
        let body = Body(format: 1, table: table, move: move)
        let data = try Self.encode(Envelope(body: body, checksum: Self.hash(Self.encode(body))))
        guard data.count <= Self.maximumBytes else { throw TableError.invalidState }
        let compressed = try (data as NSData).compressed(using: .lzfse) as Data
        var components = URLComponents()
        // MSMessage strips custom URL schemes; data carries the table without a web destination.
        components.scheme = "data"
        components.path = ",river"
        components.queryItems = [URLQueryItem(name: "g", value: Self.base64(compressed))]
        guard let url = components.url, url.absoluteString.utf8.count <= 5_000 else { throw TableError.invalidState }
        return url
    }

    public init(url: URL) throws {
        guard url.absoluteString.utf8.count <= 5_000,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw TableError.invalidState }
        let query = components.queryItems
        if query?.contains(where: { $0.name == "r" }) == true {
            let legacy = try LegacyMessage(url: url)
            table = legacy.table
            move = legacy.move
            fingerprint = try Self.digest(table)
            legacyURL = url
            legacyBranch = legacy.branch
            return
        }
        guard components.scheme == "data", components.host == nil, components.path == ",river",
              components.user == nil, components.password == nil, components.port == nil,
              components.fragment == nil, let query, query.count == 1,
              query[0].name == "g", let value = query[0].value else { throw TableError.invalidState }
        let data = try Self.decompress(Self.decodeBase64(value))
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        // Canonical bytes reject duplicate/unknown keys and ambiguous numeric encodings.
        guard try Self.encode(envelope) == data, envelope.body.format == 1,
              envelope.checksum == Self.hash(try Self.encode(envelope.body)),
              Table.validID(envelope.body.move.actor),
              Self.isDigest(envelope.body.move.parent),
              (0...253_402_300_000_000).contains(envelope.body.move.time) else { throw TableError.invalidState }
        table = try envelope.body.table.validated()
        move = envelope.body.move
        fingerprint = try Self.digest(table)
        legacyURL = nil
        legacyBranch = nil
    }

    static func digest(_ table: Table) throws -> String { try hash(encode(table)) }

    private static func isDigest(_ text: String) -> Bool {
        text.utf8.count == 64 && text.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func base64(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    static func decodeBase64(_ text: String) throws -> Data {
        let encoded = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = String(repeating: "=", count: (4 - encoded.utf8.count % 4) % 4)
        guard let data = Data(base64Encoded: encoded + padding), !data.isEmpty, base64(data) == text else {
            throw TableError.invalidState
        }
        return data
    }

    static func decompress(_ data: Data) throws -> Data {
        var output = [UInt8](repeating: 0, count: maximumBytes + 1)
        let count = data.withUnsafeBytes { source in
            output.withUnsafeMutableBytes { destination -> Int? in
                var stream = compression_stream(
                    dst_ptr: destination.bindMemory(to: UInt8.self).baseAddress!, dst_size: destination.count,
                    src_ptr: source.bindMemory(to: UInt8.self).baseAddress!, src_size: source.count, state: nil)
                guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_LZFSE) == COMPRESSION_STATUS_OK else {
                    return nil
                }
                defer { compression_stream_destroy(&stream) }
                stream.src_ptr = source.bindMemory(to: UInt8.self).baseAddress!
                stream.src_size = source.count
                stream.dst_ptr = destination.bindMemory(to: UInt8.self).baseAddress!
                stream.dst_size = destination.count
                let status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                guard status == COMPRESSION_STATUS_END, stream.src_size == 0, stream.dst_size > 0 else { return nil }
                return destination.count - stream.dst_size
            }
        }
        guard let count, count > 0 else { throw TableError.invalidState }
        return Data(output.prefix(count))
    }
}
