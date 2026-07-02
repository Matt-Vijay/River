import Foundation

extension GamePayload {
    static func makeURL<T: Encodable>(host: String, payload: T) throws -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: queryKey, value: try encodeToPayload(payload))]
        guard let url = components.url else {
            throw EncodingError.invalidValue(payload, .init(
                codingPath: [], debugDescription: "Could not build URL"))
        }
        return url
    }

    static func payloadString(in url: URL, description: String) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: description))
        }
        let payloads = queryItems.filter { $0.name == queryKey }
        guard payloads.count == 1, let value = payloads[0].value else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: description))
        }
        return value
    }

    static func payloadString(in url: URL, host expectedHost: String,
                              description: String) throws -> String {
        guard url.scheme == scheme, url.host == expectedHost else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Expected \(expectedHost) payload URL"))
        }
        return try payloadString(in: url, description: description)
    }
}
