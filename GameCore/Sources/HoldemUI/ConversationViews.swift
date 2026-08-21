import GameCore
import SwiftUI

public struct ConversationNewTableView: View {
  private let onSend: () -> Void

  public init(onSend: @escaping () -> Void) {
    self.onSend = onSend
  }

  public var body: some View {
    Button(action: onSend) {
      VStack(spacing: 14) {
        PokerChipMark(size: 56)
        Text("Texas Hold’em")
          .font(.title3.weight(.semibold))
          .foregroundStyle(.white)
        Label("Send table", systemImage: "paperplane.fill")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Theme.secondaryText)
      }
      .frame(maxWidth: .infinity, minHeight: 190)
      .controlSurface()
      .contentShape(RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner))
    }
    .buttonStyle(PressableButtonStyle())
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.background)
    .accessibilityLabel("Send Texas Hold’em table")
    .accessibilityIdentifier(HoldemAccessibility.Conversation.sendTable)
  }
}

public struct ConversationGameEntryView: View {
  private let summary: String
  private let onJoin: (() -> Void)?

  public init(
    summary: String,
    onJoin: (() -> Void)?
  ) {
    self.summary = summary
    self.onJoin = onJoin
  }

  public var body: some View {
    ConversationPrompt(
      title: onJoin == nil ? "Table full" : "Game in progress",
      message: summary
    ) {
      if let onJoin {
        PrimaryActionButton(
          title: "Join next hand",
          accessibilityID: HoldemAccessibility.Conversation.joinGame,
          action: onJoin)
      } else {
        Text("Try again when a seat opens.")
          .font(.subheadline.weight(.medium))
      }
    }
    .accessibilityIdentifier(
      onJoin == nil ? HoldemAccessibility.Conversation.tableFull : "")
  }
}

struct ConversationPrompt<Accessory: View>: View {
  let title: String
  let message: String
  var messageAccessibilityID = ""
  @ViewBuilder var accessory: Accessory

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        Text(title)
          .font(.title3.weight(.semibold))
          .stableOneLineText(minScale: 0.78)
          .accessibilityAddTraits(.isHeader)
        Text(message)
          .font(.subheadline)
          .foregroundStyle(Theme.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier(messageAccessibilityID)
        accessory
      }
      .foregroundStyle(.white)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 32)
      .padding(.vertical, 36)
      .frame(maxWidth: .infinity)
      .containerRelativeFrame(.vertical, alignment: .center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.background)
  }
}

public struct CompactSummaryView: View {
  private let summary: String
  private let onOpen: () -> Void

  public init(summary: String, onOpen: @escaping () -> Void) {
    self.summary = summary
    self.onOpen = onOpen
  }

  public var body: some View {
    Button(action: onOpen) {
      HStack {
        HStack(spacing: 8) {
          PokerChipMark()
          Text("River").font(.body.weight(.semibold))
        }
        .foregroundStyle(.white)
        .fixedSize(horizontal: true, vertical: false)

        Spacer(minLength: 12)

        Text(summary)
          .font(.subheadline)
          .foregroundStyle(Theme.secondaryText)
          .stableOneLineText(accessibilityLineLimit: nil, alignment: .trailing)
          .fixedSize(horizontal: false, vertical: true)
          .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)

        Image(systemName: "arrow.up.forward.app")
          .foregroundStyle(Theme.secondaryText)
          .frame(width: 18, alignment: .trailing)
      }
      .padding(.horizontal, 16)
      .frame(maxWidth: .infinity, minHeight: 64)
      .controlSurface()
      .contentShape(RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner))
    }
    .buttonStyle(PressableButtonStyle())
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.background)
    .accessibilityLabel("Open table. \(summary)")
    .accessibilityIdentifier(HoldemAccessibility.Conversation.openTable)
  }
}

private struct PokerChipMark: View {
  var size: CGFloat = 16

  var body: some View {
    ZStack {
      Circle().fill(.white)
      Circle().stroke(.black, lineWidth: size / 8).padding(size / 4)
      ForEach(0..<8) { index in
        RoundedRectangle(cornerRadius: 1)
          .fill(.black)
          .frame(width: size / 8, height: size * 3 / 8)
          .offset(y: -size * 3 / 8)
          .rotationEffect(.degrees(Double(index) * 45))
      }
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

public struct GameOverView: View {
  private let summary: String
  private let onNewTable: () -> Void

  public init(summary: String, onNewTable: @escaping () -> Void) {
    self.summary = summary
    self.onNewTable = onNewTable
  }

  public var body: some View {
    ConversationPrompt(
      title: "Game over",
      message: summary,
      messageAccessibilityID: HoldemAccessibility.Table.result
    ) {
      PrimaryActionButton(
        title: "New table",
        accessibilityID: HoldemAccessibility.Table.newTable,
        action: onNewTable
      )
    }
    .accessibilityIdentifier(HoldemAccessibility.Conversation.gameOver)
  }
}

public struct StaleTableView: View {
  public enum Context {
    case olderMessage
    case rejectedAction(TableOperationRejection)
    case invalidPayload
    case encodingFailed
    case sendFailed
  }

  private let summary: String
  private let context: Context
  private let onClose: () -> Void

  public init(
    summary: String,
    context: Context = .olderMessage,
    onClose: @escaping () -> Void
  ) {
    self.summary = summary
    self.context = context
    self.onClose = onClose
  }

  public var body: some View {
    let details = Self.details(for: context)
    ConversationPrompt(
      title: details.title,
      message: summary
    ) {
      Text(details.guidance)
        .font(.subheadline.weight(.medium))
        .fixedSize(horizontal: false, vertical: true)
      PrimaryActionButton(
        title: "Back to Messages",
        accessibilityID: HoldemAccessibility.Conversation.closeRecovery,
        action: onClose)
    }
    .accessibilityIdentifier(HoldemAccessibility.Conversation.recovery)
  }

  private static func details(for context: Context) -> (title: String, guidance: String) {
    switch context {
    case .olderMessage:
      ("Older table message", "Open the newest River message to continue.")
    case .rejectedAction(let reason):
      ("Action not sent", rejectionGuidance(reason))
    case .invalidPayload:
      (
        "Could not open table",
        "This message has invalid table data. Open the newest River message."
      )
    case .encodingFailed:
      (
        "Could not send table",
        "Open the newest River message and try again."
      )
    case .sendFailed:
      (
        "Could not send action",
        "Messages could not send the update. Try again from the newest River message."
      )
    }
  }

  private static func rejectionGuidance(_ reason: TableOperationRejection) -> String {
    switch reason {
    case .stale, .wrongPhase:
      "Open the newest River message, then try again."
    case .notSeated:
      "Join this table before taking that action."
    case .notActorTurn:
      "It is not your turn."
    case .illegalAction:
      "That move is not legal right now."
    case .tableFull:
      "This table is full."
    case .gameOver:
      "This game is already over."
    }
  }
}
