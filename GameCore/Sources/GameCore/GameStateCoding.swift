import Foundation

private struct GameStateAnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

extension GameState {
    public init(from decoder: Decoder) throws {
        let shape = try decoder.container(keyedBy: GameStateAnyCodingKey.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let requiresCanonicalNumbers =
            (decoder.userInfo[GamePayload.wireVersionKey] as? Int ?? 2) >= 2
        let allowedKeys: Set<String> = [
            "tableID", "handNumber", "players", "dealerIndex", "smallBlind", "bigBlind",
            "board", "deck", "pot", "street", "currentToAct", "minRaise",
            "turnStartedAt", "turnDuration", "results", "version",
        ]
        guard Set(shape.allKeys.map(\.stringValue)).isSubset(of: allowedKeys) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: container.codingPath,
                      debugDescription: "Unknown game state fields"))
        }
        let tableID = try container.decodeIfPresent(String.self, forKey: .tableID)
            .map {
                try Identity.decoded(
                    $0,
                    error: "Blank table identity",
                    codingPath: container.codingPath + [CodingKeys.tableID]
                )
            }
            ?? GamePayload.legacyTableID(from: decoder)
        let players = try container.decode([Player].self, forKey: .players)
        try Identity.requireUnique(
            players.map(\.id),
            codingPath: container.codingPath + [CodingKeys.players]
        )
        guard (TableRules.minPlayers...TableRules.maxPlayers).contains(players.count) else {
            throw DecodingError.dataCorruptedError(
                forKey: .players, in: container,
                debugDescription: "Table has an unsupported player count")
        }
        guard players.allSatisfy({ $0.holeCards.isEmpty || $0.holeCards.count == 2 }) else {
            throw DecodingError.dataCorruptedError(
                forKey: .players, in: container,
                debugDescription: "Players must have zero or two hole cards")
        }
        let board = try container.decode([Card].self, forKey: .board)
        let deck = try container.decode([Card].self, forKey: .deck)
        guard board.count <= 5 else {
            throw DecodingError.dataCorruptedError(
                forKey: .board, in: container,
                debugDescription: "Board cannot contain more than five cards")
        }
        let wirePot = try container.decode(Int.self, forKey: .pot)
        let cards = players.flatMap(\.holeCards) + board + deck
        guard cards.count == 52, Set(cards).count == cards.count else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: container.codingPath,
                debugDescription: "A game must contain 52 unique cards"
            ))
        }
        let results = try container.decodeIfPresent([HandResult].self, forKey: .results)
        if let results, Set(results.map(\.playerID)).count != results.count {
            throw DecodingError.dataCorruptedError(
                forKey: .results, in: container,
                debugDescription: "A player may have only one result")
        }
        let wireHandNumber = try container.decode(Int.self, forKey: .handNumber)
        let wireSmallBlind = try container.decode(Int.self, forKey: .smallBlind)
        let wireBigBlind = try container.decode(Int.self, forKey: .bigBlind)
        let blinds = TableRules.normalizedBlinds(
            smallBlind: wireSmallBlind, bigBlind: wireBigBlind)
        let dealerIndex = try container.decode(Int.self, forKey: .dealerIndex)
        guard players.indices.contains(dealerIndex) else {
            throw DecodingError.dataCorruptedError(
                forKey: .dealerIndex, in: container,
                debugDescription: "Dealer seat is outside the table")
        }
        let wireMinRaise = try container.decode(Int.self, forKey: .minRaise)
        let wireVersion = decoder.userInfo[GamePayload.wireVersionKey] as? Int ?? 2
        let stateVersion = try container.decodeIfPresent(Int.self, forKey: .version)
        let wireTurnDuration = try container.decode(TimeInterval.self, forKey: .turnDuration)
        let wireTurnStartedAt = try container.decodeIfPresent(Date.self, forKey: .turnStartedAt)
        if requiresCanonicalNumbers {
            guard wireHandNumber >= 1,
                  stateVersion.map({ $0 >= 0 }) == true,
                  blinds.smallBlind == wireSmallBlind,
                  blinds.bigBlind == wireBigBlind,
                  (0...TableRules.tableMaximum).contains(wirePot),
                  wireTurnDuration.isFinite,
                  wireTurnDuration > 0,
                  wireTurnDuration <= TurnClock.maximumDuration,
                  wireTurnStartedAt.map(TurnClock.isSaneWireDate) ?? true,
                  results == nil
                    ? (blinds.bigBlind...TableRules.tableMaximum).contains(wireMinRaise)
                    : wireMinRaise == 0 else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: container.codingPath,
                          debugDescription: "Game numeric fields are not canonical"))
            }
        }
        self = GameState(
            tableID: tableID,
            handNumber: max(1, wireHandNumber),
            players: players,
            dealerIndex: dealerIndex,
            smallBlind: blinds.smallBlind,
            bigBlind: blinds.bigBlind,
            board: board,
            deck: deck,
            street: try container.decode(Street.self, forKey: .street),
            currentToAct: try container.decodeIfPresent(Int.self, forKey: .currentToAct),
            minRaise: results == nil
                ? TableRules.table(max(blinds.bigBlind, wireMinRaise))
                : 0,
            turnStartedAt: wireTurnStartedAt,
            turnDuration: TurnClock.normalized(wireTurnDuration),
            results: results,
            version: max(0, stateVersion ?? 0)
        )
        migrateLegacyResultsIfNeeded(wireVersion: wireVersion)
        try validateDecodedIntegrity(
            wirePot: wirePot, wireMinRaise: wireMinRaise, codingPath: decoder.codingPath)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let wirePot = isHandComplete ? 0 : max(0, displayPot - players.reduce(0) {
            TableRules.adding($0, $1.bet, limit: TableRules.tableMaximum)
        })
        try container.encode(tableID, forKey: .tableID)
        try container.encode(handNumber, forKey: .handNumber)
        try container.encode(players, forKey: .players)
        try container.encode(dealerIndex, forKey: .dealerIndex)
        try container.encode(smallBlind, forKey: .smallBlind)
        try container.encode(bigBlind, forKey: .bigBlind)
        try container.encode(board, forKey: .board)
        try container.encode(deck, forKey: .deck)
        try container.encode(wirePot, forKey: .pot)
        try container.encode(street, forKey: .street)
        try container.encodeIfPresent(currentToAct, forKey: .currentToAct)
        try container.encode(minRaise, forKey: .minRaise)
        try container.encodeIfPresent(turnStartedAt, forKey: .turnStartedAt)
        try container.encode(turnDuration, forKey: .turnDuration)
        try container.encodeIfPresent(results, forKey: .results)
        try container.encode(version, forKey: .version)
    }
}

private extension GameState {
    mutating func migrateLegacyResultsIfNeeded(wireVersion: Int) {
        guard wireVersion < 2, results != nil else { return }

        // Early River payloads counted a one-contributor layer as winnings.
        // Correct settlement treats it as an uncalled refund. The winner's stack
        // was already the same either way, so rebuild presentation metadata while
        // retaining the historical chip stacks and contributions.
        let ranks = contenders.count > 1 ? showdownRanks() : [:]
        let winnings = settlement(ranks: ranks).winnings
        results = players.indices.compactMap { index in
            let playerID = players[index].id
            guard let amount = winnings[playerID], amount > 0 else { return nil }
            return HandResult(
                playerID: playerID,
                amountWon: amount,
                handName: ranks[index]?.name,
                bestFive: ranks[index]?.bestFive
            )
        }
    }

    func validateDecodedIntegrity(
        wirePot: Int, wireMinRaise: Int, codingPath: [CodingKey]
    ) throws {
        let contenders = players.filter(\.isContesting)
        guard players.allSatisfy({ player in
            switch player.status {
            case .active, .folded, .allIn:
                player.holeCards.count == 2
            case .sittingOut:
                results != nil || player.holeCards.isEmpty
            case .eliminated:
                player.holeCards.isEmpty
            }
        }) else {
            throw corrupted("Player status does not match dealt cards", codingPath: codingPath)
        }
        if let results {
            guard !results.isEmpty else {
                throw corrupted("Completed hand requires a positive award", codingPath: codingPath)
            }
            guard street == .showdown,
                  currentToAct == nil,
                  turnStartedAt == nil,
                  wirePot == 0,
                  wireMinRaise == 0,
                  players.allSatisfy({ $0.bet == 0 && $0.lastActionBet == nil }) else {
                throw corrupted("Completed hand contains live betting state", codingPath: codingPath)
            }
            guard results.allSatisfy({ $0.amountWon > 0 }) else {
                throw corrupted("Completed hand requires positive awards", codingPath: codingPath)
            }
            let contenderIDs = Set(contenders.map(\.id))
            guard results.allSatisfy({ contenderIDs.contains($0.playerID) }) else {
                throw corrupted("Only contesting players may receive awards", codingPath: codingPath)
            }
            let totalCommitted = try checkedSum(
                players.map(\.committed),
                codingPath: codingPath
            )
            let totalWinnings = try checkedSum(
                results.map(\.amountWon),
                codingPath: codingPath
            )
            if contenders.count > 1 {
                guard board.count == 5,
                      contenders.allSatisfy({ $0.holeCards.count == 2 }) else {
                    throw corrupted("Showdown requires complete visible cards", codingPath: codingPath)
                }
            }
            let ranks = showdownRanks()
            let settlement = settlement(ranks: ranks)
            guard totalWinnings == totalCommitted - settlement.refundedTotal else {
                throw corrupted("Result winnings do not match claimable chips", codingPath: codingPath)
            }
            let reported = Dictionary(
                uniqueKeysWithValues: results.map { ($0.playerID, $0.amountWon) }
            )
            guard reported == settlement.winnings.filter({ $0.value > 0 }) else {
                throw corrupted("Result winnings do not match poker winners", codingPath: codingPath)
            }
            if contenders.count > 1 {
                let playerIndexes = Dictionary(
                    uniqueKeysWithValues: players.indices.map { (players[$0].id, $0) }
                )
                guard results.allSatisfy({ result in
                    guard let index = playerIndexes[result.playerID],
                          let rank = ranks[index],
                          let reportedCards = result.bestFive,
                          Set(reportedCards).isSubset(
                            of: Set(players[index].holeCards + board)
                          ) else { return false }
                    let reportedRank = HandEvaluator.evaluate(reportedCards)
                    return result.handName == rank.name
                        && reportedRank == rank
                }) else {
                    throw corrupted("Result hand details do not match poker hands", codingPath: codingPath)
                }
            } else if results.contains(where: {
                $0.handName != nil || $0.bestFive != nil
            }) {
                throw corrupted("Uncontested results cannot include hand details", codingPath: codingPath)
            }
            return
        }

        guard contenders.count >= 2 else {
            throw corrupted("Live hand requires at least two contenders", codingPath: codingPath)
        }
        guard street != .showdown else {
            throw corrupted("Showdown requires completed results", codingPath: codingPath)
        }
        guard players.allSatisfy({ !$0.canAct || $0.stack > 0 }) else {
            throw corrupted("Active players require chips", codingPath: codingPath)
        }
        guard players.allSatisfy({ $0.status != .allIn || $0.stack == 0 }) else {
            throw corrupted("All-in players cannot retain chips", codingPath: codingPath)
        }
        guard players.allSatisfy({ !$0.hasLeft || !$0.canAct }) else {
            throw corrupted("Departed players cannot remain active", codingPath: codingPath)
        }
        guard players.allSatisfy({ player in
            player.lastActionBet == nil || player.lastActionBet == player.bet
        }) else {
            throw corrupted("Player action markers must match current bets", codingPath: codingPath)
        }
        guard let currentToAct,
              players.indices.contains(currentToAct),
              players[currentToAct].canAct else {
            throw corrupted("Live hand requires an active actor", codingPath: codingPath)
        }
        let actor = players[currentToAct]
        guard actor.lastActionBet.map({ $0 < currentBet }) ?? true else {
            throw corrupted("Live actor must have a pending action", codingPath: codingPath)
        }
        guard turnStartedAt != nil else {
            throw corrupted("Live actor requires a turn start time", codingPath: codingPath)
        }
        guard board.count == street.boardCount else {
            throw corrupted("Board does not match the betting street", codingPath: codingPath)
        }
        guard contenders.allSatisfy({ $0.holeCards.count == 2 }) else {
            throw corrupted("Contesting players require two hole cards", codingPath: codingPath)
        }
        guard deck.count >= max(0, 5 - board.count) else {
            throw corrupted("Live hand cannot finish the board", codingPath: codingPath)
        }
        let totalBets = try checkedSum(players.map(\.bet), codingPath: codingPath)
        let totalCommitted = try checkedSum(players.map(\.committed), codingPath: codingPath)
        guard totalCommitted >= totalBets,
              (0...TableRules.tableMaximum).contains(wirePot),
              wirePot == totalCommitted - totalBets else {
            throw corrupted("Committed chips do not match the pot", codingPath: codingPath)
        }

        _ = try checkedSum(
            players.flatMap { [$0.stack, $0.committed] },
            codingPath: codingPath
        )
        for player in players {
            let liveBankroll = try checkedSum(
                [player.stack, player.committed],
                codingPath: codingPath
            )
            guard liveBankroll <= TableRules.tableMaximum else {
                throw corrupted("Player bankroll exceeds supported range", codingPath: codingPath)
            }
        }
    }

    func checkedSum(_ values: [Int], codingPath: [CodingKey]) throws -> Int {
        try values.reduce(0) { total, value in
            let result = total.addingReportingOverflow(value)
            guard !result.overflow else {
                throw corrupted("Chip totals exceed supported range", codingPath: codingPath)
            }
            return result.partialValue
        }
    }

    func corrupted(_ description: String, codingPath: [CodingKey]) -> DecodingError {
        .dataCorrupted(.init(codingPath: codingPath, debugDescription: description))
    }
}
