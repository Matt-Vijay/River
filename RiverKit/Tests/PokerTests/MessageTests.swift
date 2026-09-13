import Compression
import CryptoKit
import Foundation
import Testing
@testable import Poker

struct MessageTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000.123456)

    @Test func composedNamesSurviveMessages() throws {
        let emoji = "\u{1F469}\u{200D}\u{1F4BB}"
        for name in ["Sam \(emoji)", "\u{0639}\u{0644}\u{06CC}\u{200C}\u{0631}\u{0636}\u{0627}"] {
            let profile = try #require(Profile(name: name, avatar: "S"))
            #expect(profile.name == name)
            let message = try TableMessage(recording: .join(profile), on: Table(id: "test"), actor: "sender", at: now)
            #expect(try TableMessage(url: message.url()).table.seat("sender")?.profile == profile)
        }
        #expect(Profile(name: " \u{200C}\u{200D} ", avatar: "S") == nil)
        #expect(Profile.boundedName("\u{202E}Sam\n") == "Sam")
        #expect(Profile.boundedName(String(repeating: emoji, count: 10)) == String(repeating: emoji, count: 8))
    }

    @Test func invitationAndExactReplay() throws {
        let empty = Table(id: "conversation")
        let message = try TableMessage(recording: .join(Profile(name: "Morgan", avatar: "M")!), on: empty, actor: "sender", at: now)
        let url = try message.url()
        #expect(url.absoluteString.utf8.count < 5_000)
        let decoded = try TableMessage(url: url)
        #expect(decoded.table == message.table)
        #expect(decoded.verifies(after: empty))
        #expect(decoded.move.time == 1_800_000_000_123)
        let joined = try TableMessage(recording: .join(Profile(name: "Sam", avatar: "S")!), on: decoded.table, actor: "receiver", at: now)
        #expect(joined.verifies(after: decoded.table))
        #expect(joined.isNewer(than: decoded))
        #expect(!joined.verifies(after: empty))
        #expect(!decoded.isNewer(than: joined))
    }

    @Test func malformedAndAmbiguousMessagesAreRejected() throws {
        let message = try TableMessage(recording: .join(Profile(name: "Morgan", avatar: "M")!), on: Table(id: "test"), actor: "sender", at: now)
        let url = try message.url()
        for invalid in [url.absoluteString + "&g=duplicate", url.absoluteString + "#extra",
                        url.absoluteString + "=", "data:,river?g=AAAA", "https://table?g=AAAA",
                        "data://user@table?g=AAAA", "data:,river?g=" + String(repeating: "a", count: 5_000)] {
            #expect(throws: (any Error).self) { try TableMessage(url: #require(URL(string: invalid))) }
        }
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let value = try #require(components.queryItems?.first?.value)
        let padded = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            + String(repeating: "=", count: (4 - value.count % 4) % 4)
        let compressed = try #require(Data(base64Encoded: padded))
        let data = try (compressed as NSData).decompressed(using: .lzfse) as Data
        var root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        root["extra"] = true
        #expect(throws: (any Error).self) { try TableMessage(url: encoded(try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]))) }
        var tampered = try #require(String(data: data, encoding: .utf8))
        tampered = tampered.replacingOccurrences(of: "Morgan", with: "Forged")
        #expect(throws: (any Error).self) { try TableMessage(url: encoded(Data(tampered.utf8))) }
        let duplicated = Data(("{\"checksum\":\"forged\"," + String(decoding: data.dropFirst(), as: UTF8.self)).utf8)
        #expect(throws: (any Error).self) { try TableMessage(url: encoded(duplicated)) }
        #expect(throws: (any Error).self) { try TableMessage(url: encoded(Data(repeating: 0x20, count: 25_000))) }
    }

    private func encoded(_ data: Data) throws -> URL {
        let packed = try (data as NSData).compressed(using: .lzfse) as Data
        let value = packed.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return try #require(URL(string: "data:,river?g=" + value))
    }
}
