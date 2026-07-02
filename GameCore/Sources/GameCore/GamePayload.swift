import Foundation

/// Packs game data into compact, URL-safe forms for iMessage payloads.
public enum GamePayload {
    /// Query item key carrying the encoded state in the message URL.
    public static let queryKey = "g"
    /// Custom scheme for the carrier URL. The value is opaque to Messages.
    public static let scheme = "holdem"
}
