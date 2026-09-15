import Poker
import SwiftUI

public struct RiverRoot: View {
    private let session: RiverSession
    private let observesScenePhase: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var profileName = ""
    @State private var profileAvatar = Characters.all[0]

    public init(session: RiverSession, observesScenePhase: Bool = true) {
        self.session = session
        self.observesScenePhase = observesScenePhase
    }

    public var body: some View {
        ZStack {
            Group {
                if session.isCompact, session.profile == nil {
                    compactPrompt
                } else if session.profile == nil {
                    ProfileScreen(onSave: session.save, name: $profileName, avatar: $profileAvatar)
                } else {
                    switch session.surface {
                    case .invitation: InvitationScreen(session: session)
                    case .table(let table):
                        // Collapsing Messages must preserve the table's seat map and scroll position.
                        ZStack {
                            Group {
                                if table.hand != nil {
                                    GameScreen(session: session, table: table).id(table.id)
                                } else if session.isLocal || table.seat(session.viewerID)?.hasLeft == false {
                                    LobbyScreen(session: session, table: table)
                                } else {
                                    EntryScreen(session: session, table: table)
                                }
                            }
                            .opacity(session.isCompact ? 0 : 1)
                            .allowsHitTesting(!session.isCompact)
                            .accessibilityElement(children: .contain)
                            .accessibilityHidden(session.isCompact)
                            if session.isCompact { compactPrompt }
                        }
                    case .unavailable(let reason):
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                Text(reason).foregroundStyle(.secondary)
                                Button("Close", systemImage: "xmark") { session.perform(.close) }
                                    .frame(minHeight: 44)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24).padding(.bottom, 24)
                        }
                        .clipped()
                        .safeAreaInset(edge: .top, spacing: 0) {
                            Text("Table unavailable").font(.headline)
                                .lineLimit(1).minimumScaleFactor(0.5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(24).avoidingWindowControls()
                        }
                        .accessibilityIdentifier("table.recovery")
                    }
                }
            }
            .disabled(session.isSending)
            .allowsHitTesting(!session.isSending)
            .accessibilityHidden(session.isSending)
            if session.isSending {
                Color.black.opacity(0.12).ignoresSafeArea()
                ProgressView("Sending table")
                    .padding(24).background(.background, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityAddTraits(.isModal)
                    .accessibilityIdentifier("table.sending")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .tint(.white)
        .alert(
            session.error ?? "",
            isPresented: Binding(get: { session.error != nil }, set: { if !$0 { session.error = nil } })
        ) {
            Button("OK") { session.error = nil }
        }
        .onChange(of: scenePhase) {
            guard observesScenePhase else { return }
            session.isVisible = scenePhase == .active
            if session.isVisible { session.refreshProfile() }
        }
    }

    private var compactPrompt: some View {
        Button {
            session.perform(.expand)
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.profile == nil ? "Set up player" : "Open table").font(.headline)
                    if let table = session.table {
                        Text(table.summary).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .padding(24).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier("conversation.expand")
    }
}

private struct InvitationScreen: View {
    let session: RiverSession

    var body: some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: 24) {
                Brand().frame(maxWidth: .infinity, alignment: .leading)
                ActionButton(title: "Send table", id: "conversation.sendTable") { session.perform(.newTable) }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            ActionButton(title: "Send table", id: "conversation.sendTable") {
                session.perform(.newTable)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
    }
}

private struct EntryScreen: View {
    let session: RiverSession
    let table: Poker.Table

    var body: some View {
        ScrollView {
            if table.canJoin(session.localID) {
                Text("Close and reopen the table to join.")
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24).padding(.bottom, 24)
            }
        }
        .clipped()
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Text(table.canJoin(session.localID) ? "Not seated" : "Table full")
                    .font(.headline).lineLimit(1).minimumScaleFactor(0.5)
                Spacer(minLength: 8)
                Button { session.perform(.close) } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel("Close table").accessibilityIdentifier("table.close")
            }
            .padding(24).avoidingWindowControls()
        }
    }
}

public struct MessagePreview: View {
    private let table: Poker.Table
    public init(table: Poker.Table) { self.table = table }

    public var spokenDescription: String {
        var parts = ["River Texas Hold'em"]
        if let hand = table.hand { parts.append("Hand \(hand.number)") }
        parts.append(table.summary)
        if let board = table.hand?.board, !board.isEmpty {
            parts.append("Board: \(board.map(\.spoken).joined(separator: ", "))")
        }
        return (parts + ["Open table"]).joined(separator: ". ") + "."
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("River").font(.title3.weight(.semibold))
                Spacer()
                Text(table.hand.map { "Hand \($0.number)" } ?? "Texas Hold'em")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.7))
            }
            HStack(spacing: 7) {
                ForEach(0..<5, id: \.self) { index in
                    let board = table.hand?.board ?? []
                    PlayingCard(card: board.indices.contains(index) ? board[index] : nil)
                }
            }
            .frame(maxWidth: 250)
            HStack(alignment: .firstTextBaseline) {
                Text(table.summary).font(.subheadline.weight(.semibold))
                    .lineLimit(2, reservesSpace: true).truncationMode(.head)
                Spacer()
                Image(systemName: "arrow.up.right").font(.subheadline.weight(.semibold))
            }
        }
        // Messages overlays its app badge at the image's upper-left corner.
        .padding(.horizontal, 20).padding(.top, 30).padding(.bottom, 10)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RiverStyle.felt)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenDescription)
    }
}
