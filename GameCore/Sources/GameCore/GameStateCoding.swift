import Foundation

enum GameStateCodingKeys: String, CodingKey {
    case tableID, appliedOperationIDs, handNumber, players, dealerIndex, smallBlind, bigBlind
    case board, deck, pot, street, currentToAct, currentBet, minRaise
    case turnStartedAt, turnDuration, results, version
}

extension GameState: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: GameStateCodingKeys.self)
        self = GameState(
            tableID: try container.decodeIfPresent(String.self, forKey: .tableID) ?? UUID().uuidString,
            appliedOperationIDs: try container.decodeIfPresent([String].self, forKey: .appliedOperationIDs) ?? [],
            handNumber: try container.decode(Int.self, forKey: .handNumber),
            players: try container.decode([Player].self, forKey: .players),
            dealerIndex: try container.decode(Int.self, forKey: .dealerIndex),
            smallBlind: try container.decode(Int.self, forKey: .smallBlind),
            bigBlind: try container.decode(Int.self, forKey: .bigBlind),
            board: try container.decode([Card].self, forKey: .board),
            deck: try container.decode([Card].self, forKey: .deck),
            pot: try container.decode(Int.self, forKey: .pot),
            street: try container.decode(Street.self, forKey: .street),
            currentToAct: try container.decodeIfPresent(Int.self, forKey: .currentToAct),
            currentBet: try container.decode(Int.self, forKey: .currentBet),
            minRaise: try container.decode(Int.self, forKey: .minRaise),
            turnStartedAt: try container.decodeIfPresent(Date.self, forKey: .turnStartedAt),
            turnDuration: try container.decode(TimeInterval.self, forKey: .turnDuration),
            results: try container.decodeIfPresent([HandResult].self, forKey: .results),
            version: try container.decode(Int.self, forKey: .version)
        )
    }
}
