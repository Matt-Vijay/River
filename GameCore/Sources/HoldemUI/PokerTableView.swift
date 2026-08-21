import SwiftUI
import GameCore

extension PlayerStatus {
    var spokenDescription: String {
        switch self {
        case .allIn: "all in"
        case .sittingOut: "sitting out"
        default: rawValue
        }
    }
}

struct PokerTableContext: Sendable {
    let state: GameState
    let heroIndex: Int
    let heroHandName: String?
    private let hasShowdown: Bool
    let winningCards: Set<Card>?
    let showdownHandLabel: String?
    private let winnerIDs: Set<String>

    init?(state: GameState, heroID: String) {
        guard let heroIndex = state.playerIndex(id: heroID) else { return nil }
        self.state = state
        self.heroIndex = heroIndex
        heroHandName = state.players[heroIndex].isContesting
            ? state.currentHandName(for: heroIndex)
            : nil
        let results = state.results ?? []
        let handNames = Set(results.compactMap(\.handName))
        let cards = Set(results.compactMap(\.bestFive).flatMap { $0 })
        hasShowdown = !handNames.isEmpty
        winningCards = cards.isEmpty ? nil : cards
        showdownHandLabel = handNames.count == 1 ? handNames.first : nil
        winnerIDs = Set(results.map(\.playerID))
    }

    var hero: Player {
        state.players[heroIndex]
    }

    var leaveConsequence: String {
        if state.isHandComplete {
            return "The completed hand will stay recorded. You will sit out future hands."
        }
        if hero.status == .folded {
            return "Your hand is already folded. You will sit out future hands."
        }
        if hero.status == .allIn {
            return "Your all-in hand remains eligible for this pot. You will sit out future hands."
        }
        return "Your current hand will be folded. You will sit out future hands."
    }

    func revealedCards(for player: Player) -> [Card]? {
        guard hasShowdown, player.isContesting, player.holeCards.count == 2 else {
            return nil
        }
        return player.holeCards
    }

    func didWin(_ player: Player) -> Bool {
        winnerIDs.contains(player.id)
    }

    func lastActionLabel(for player: Player) -> String? {
        switch player.lastAction {
        case .fold: "Fold"
        case .check: "Check"
        case .call: "Call"
        case .raise: "Raise"
        case .none: nil
        }
    }
}

/// The full poker table for a viewer whose seat has already been validated.
public struct PokerTableView: View {
    private let context: PokerTableContext
    private let onOperation: (TableOperation) -> Void

    public init?(state: GameState, heroID: String,
                 onOperation: @escaping (TableOperation) -> Void) {
        guard !state.isGameOver,
              let context = PokerTableContext(state: state, heroID: heroID) else { return nil }
        self.init(context: context, onOperation: onOperation)
    }

    init(context: PokerTableContext,
         onOperation: @escaping (TableOperation) -> Void) {
        self.context = context
        self.onOperation = onOperation
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            table.environment(\.tableNow, timeline.date)
        }
    }

    private var table: some View {
        GeometryReader { geometry in
            let seats = PokerTableSeatsRow(context: context)
            let controls = PokerTableBottomControls(context: context, onOperation: onOperation)
            let heroDock = HeroHandDock(context: context)

            if geometry.size.width > geometry.size.height {
                ScrollView(.vertical) {
                    HStack(alignment: .bottom, spacing: 24) {
                        VStack(spacing: 12) {
                            seats
                                .padding(.leading, 52)

                            tableBoard
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        VStack(spacing: 16) {
                            controls
                            heroDock
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        seats
                            .padding(.top, 12)
                            .padding(.leading, 52)

                        Spacer(minLength: 16)

                        tableBoard
                            .padding(.horizontal, 20)

                        Spacer(minLength: 16)

                        controls.padding(.horizontal, 20)

                        heroDock
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minHeight: geometry.size.height)
                }
                .defaultScrollAnchor(.bottom)
                .scrollIndicators(.hidden)
            }
        }
        .background(Theme.background)
        .overlay(alignment: .topLeading) {
            LeaveTableButton(consequence: context.leaveConsequence) {
                onOperation(.leaveGame)
            }
        }
    }

    private var tableBoard: some View {
        BoardView(board: context.state.board, pot: context.state.displayPot,
                  winningCards: context.winningCards, handLabel: context.showdownHandLabel)
    }
}

private struct PokerTableBottomControls: View {
    @Environment(\.tableNow) private var now

    let context: PokerTableContext
    let onOperation: (TableOperation) -> Void

    var body: some View {
        // Reserve enough fixed space for the tallest state (raise panel) so
        // controls never overflow into the hero cards as modes change.
        VStack(spacing: 10) {
            ZStack {
                if context.hero.bet > 0 {
                    BetChip(amount: context.hero.bet)
                }
            }
            .frame(height: 30)

            actionContent(at: now ?? Date())
        }
        .frame(minHeight: 184, alignment: .bottom)
    }

    @ViewBuilder
    private func actionContent(at date: Date) -> some View {
        if context.state.canDealNextHand(actorID: context.hero.id) {
            VStack(spacing: 10) {
                if let resultText { ResultBanner(text: resultText) }
                PrimaryActionButton(title: "Deal next hand",
                                    accessibilityID: HoldemAccessibility.Table.dealNext,
                                    action: {
                                        onOperation(.dealNextHand(
                                            seed: UInt64.random(in: .min ... .max)))
                                    })
            }
        } else if let resultText {
            ResultBanner(text: resultText)
        } else if context.state.isTurnExpired(at: date) {
            VStack(spacing: 10) {
                ResultBanner(text: "Turn expired")
                PrimaryActionButton(title: "Resolve turn",
                                    accessibilityID: HoldemAccessibility.Table.resolveTimeout,
                                    action: { onOperation(.resolveTimeout) })
            }
        } else if context.state.isCurrentPlayer(at: context.heroIndex), legal.canFold {
            ActionBarView(legal: legal,
                          bigBlind: context.state.bigBlind,
                          pot: context.state.displayPot,
                          onAction: { onOperation(.gameAction($0)) })
        } else {
            Text(waitingText)
                .font(.body)
                .foregroundStyle(Theme.secondaryText)
                .stableOneLineText(minScale: 0.78)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Theme.Metrics.actionControlHeight)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)
                        .strokeBorder(Theme.controlStroke, lineWidth: 1)
                )
                .accessibilityLabel(waitingText)
                .accessibilityIdentifier(HoldemAccessibility.Table.waiting)
        }
    }

    private var resultText: String? {
        guard context.state.results?.isEmpty == false else { return nil }
        return GamePayload.summary(for: context.state)
    }

    private var legal: LegalActions {
        context.state.legalActions(for: context.heroIndex)
    }

    private var waitingText: String {
        if context.state.isHandComplete { return "Next hand soon" }
        if context.hero.status == .folded { return "Folded. Waiting for next hand" }
        if context.hero.status == .sittingOut { return "Joining next hand" }
        if let currentPlayer = context.state.currentPlayer {
            return "Waiting for \(currentPlayer.name)"
        }
        return "Waiting for next action"
    }
}

private struct ResultBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.headline.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.Metrics.actionControlHeight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
            .accessibilityIdentifier(HoldemAccessibility.Table.result)
    }
}

struct BetChip: View {
    let amount: Int

    var body: some View {
        Text(ChipText.string(amount))
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.chip)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.controlBackground))
    }
}
