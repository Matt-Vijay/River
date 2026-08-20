import Foundation
import Testing

@testable import GameCore

extension GameState {
  @discardableResult
  mutating func apply(
    _ action: PlayerAction, by index: Int,
    now: Date = Date()
  ) -> Bool {
    guard !isTurnExpired(at: now) else { return false }
    return applyCurrent(action, by: index, now: now)
  }
}

func makePlayers(_ stacks: [Int]) -> [Player] {
  stacks.enumerated().map { index, stack in
    Player(id: "p\(index)", name: "P\(index)", avatar: "🙂", stack: stack)
  }
}

extension Lobby {
  func fixtureSeat(id: String, name: String, avatar: String) -> Lobby {
    var copy = self
    copy.seats.append(LobbySeat(id: id, name: name, avatar: avatar))
    return copy
  }
}

func sixPlayerState() -> GameState {
  GameState.startHand(
    players: makePlayers(Array(repeating: 1000, count: 6)),
    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
    seed: 99, handNumber: 3, now: Date(timeIntervalSince1970: 1_700_000_000)
  )
}

func headsUpTableMessage() -> TableMessage {
  .game(
    GameState.startHand(
      players: [
        Player(id: "a", name: "Alice", avatar: "A", stack: 1000),
        Player(id: "b", name: "Bob", avatar: "B", stack: 1000),
      ],
      dealerIndex: 0, smallBlind: 10, bigBlind: 20,
      seed: 1, handNumber: 1, tableID: "table-123"
    ))
}

func checkOrCallToShowdown(_ state: inout GameState) {
  var actions = 0
  while let index = state.currentToAct, actions < 200 {
    let legal = state.legalActions(for: index)
    state.apply(
      legal.canCheck ? .check : .call,
      by: index, now: state.turnStartedAt ?? .distantPast)
    actions += 1
  }
}

func totalChips(_ state: GameState) -> Int {
  state.players.reduce(0) { $0 + $1.stack }
    + (state.isHandComplete ? 0 : state.displayPot)
}

func playFullHandOverTheWire(playerCount: Int, seed: UInt64) throws -> GameState {
  let initial = GameState.startHand(
    players: makePlayers(Array(repeating: 1000, count: playerCount)),
    dealerIndex: 0, smallBlind: 10, bigBlind: 20,
    seed: seed, handNumber: 1)
  let chipTotal = totalChips(initial)
  var wire = try encodedGame(initial)

  for _ in 0..<500 {
    let message = try GamePayload.decodeMessage(from: wire)
    guard case .game(let state) = message,
      let actor = state.currentToAct
    else { break }
    #expect(totalChips(state) == chipTotal)
    let legal = state.legalActions(for: actor)
    guard
      case .applied(let next) = message.committing(
        .gameAction(legal.canCheck ? .check : .call),
        actorID: state.players[actor].id
      )
    else { break }
    wire = try GamePayload.encode(next)
  }
  return try decodedGame(from: wire)
}

func encodedGame(_ state: GameState) throws -> String {
  try GamePayload.encode(.game(state))
}

func decodedGame(from wire: String) throws -> GameState {
  try decodedGame(from: GamePayload.decodeMessage(from: wire))
}

private func decodedGame(from message: TableMessage) throws -> GameState {
  guard case .game(let state) = message else {
    throw DecodingError.dataCorrupted(
      .init(codingPath: [], debugDescription: "Expected game table message")
    )
  }
  return state
}

/// Parses "Ah Td 2c" strings into cards for readable evaluator tests.
func cards(_ string: String) -> [Card] {
  string.split(separator: " ").compactMap { token in
    let rankText = String(token.dropLast())
    let rank: Rank? =
      switch rankText {
      case "A": .ace
      case "K": .king
      case "Q": .queen
      case "J": .jack
      case "T": .ten
      default: Int(rankText).flatMap(Rank.init(rawValue:))
      }
    let suit: Suit? =
      switch token.last {
      case "c": Suit.clubs
      case "d": .diamonds
      case "h": .hearts
      case "s": .spades
      default: nil
      }
    guard let rank, let suit else { return nil }
    return Card(rank: rank, suit: suit)
  }
}

func eval(_ string: String) -> HandRank {
  HandEvaluator.evaluate(cards(string))
}
