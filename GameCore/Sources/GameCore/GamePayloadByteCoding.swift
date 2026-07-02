import Foundation

extension GamePayload {
    static func encodeToPayload<T: Encodable>(_ value: T) throws -> String {
        try encoder.encode(value).base64URLEncodedString()
    }

    static func decodePayload<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        guard let data = Data(base64URLEncoded: string) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Not valid base64url"))
        }
        return try decoder.decode(type, from: data)
    }
}
