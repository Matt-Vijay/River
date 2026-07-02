import GameCore

/// Parses "Ah Td 2c" style strings into cards for readable tests.
func cards(_ string: String) -> [Card] {
    string.split(separator: " ").compactMap { token in
        let chars = Array(token)
        guard let suitChar = chars.last else { return nil }

        let rankChar = String(chars.dropLast())
        let rank: Rank
        switch rankChar {
        case "A": rank = .ace
        case "K": rank = .king
        case "Q": rank = .queen
        case "J": rank = .jack
        case "T": rank = .ten
        default:
            guard let rawRank = Int(rankChar), let parsedRank = Rank(rawValue: rawRank) else {
                return nil
            }
            rank = parsedRank
        }

        let suit: Suit
        switch suitChar {
        case "c": suit = .clubs
        case "d": suit = .diamonds
        case "h": suit = .hearts
        case "s": suit = .spades
        default:
            return nil
        }
        return Card(rank: rank, suit: suit)
    }
}

func eval(_ string: String) -> HandRank { HandEvaluator.evaluate(cards(string)) }
