import Poker
import SwiftUI

struct GameScreen: View {
    let session: RiverSession
    let table: Poker.Table
    @State private var revealedTurn: String?
    @State private var raising: RaiseSelection?
    @State private var seatIDs: [String?]
    @Environment(\.dynamicTypeSize) private var textSize

    init(session: RiverSession, table: Poker.Table) {
        self.session = session
        self.table = table
        let opponents = table.seats.filter { $0.id != session.viewerID }.map { Optional($0.id) }
        _seatIDs = State(initialValue: opponents
                         + Array(repeating: nil, count: max(0, table.rules.capacity - 1 - opponents.count)))
    }

    private var seatedIDs: [String] {
        table.seats.filter { !$0.hasLeft || table.stake($0.id) != nil }.map(\.id)
    }

    private var opponents: [Seat?] {
        seatIDs.map { id in
            guard let id, let seat = table.seat(id), !seat.hasLeft || table.stake(id) != nil else { return nil }
            return seat
        }
    }

    private var turnKey: String { "\(table.hand?.number ?? 0):\(session.viewerID)" }
    private var isPresented: Bool { session.isVisible && !session.isCompact }
    private var privateHandHidden: Bool {
        !isPresented || (session.isLocal && table.hand?.isComplete == false && revealedTurn != turnKey)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1, paused: table.hand?.isComplete != false || !isPresented)) { clock in
            VStack(spacing: 0) {
                header
                playfield(at: clock.date)
            }
        }
        .foregroundStyle(.white)
        .background(Color.black)
        .onChange(of: isPresented) {
            if !isPresented {
                revealedTurn = nil
                raising = nil
            }
        }
        .onChange(of: table.hand.map { $0.cards(for: session.viewerID) + $0.board }) { raising = nil }
        .onChange(of: turnKey) {
            revealedTurn = nil
            raising = nil
        }
        .onChange(of: [session.viewerID] + seatedIDs) { previous, _ in
            let ids = seatedIDs.filter { $0 != session.viewerID }
            var next = seatIDs
            // Passing the phone swaps only the two participants, not every seat between them.
            if let index = next.firstIndex(of: session.viewerID) { next[index] = previous.first }
            next = next.map { ids.contains($0 ?? "") ? $0 : nil }
            for id in ids where !next.contains(id) {
                if let index = next.firstIndex(of: nil) { next[index] = id }
                else { next.append(id) }
            }
            seatIDs = next
        }
        .privacySensitive()
    }

    private var header: some View {
        HStack {
            Text("Hand \(table.hand?.number ?? 1)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            Spacer()
            if table.seat(session.viewerID)?.hasLeft == false, !table.isFinished {
                LeaveButton(session: session, table: table)
            }
        }
        .padding(.leading, 20).padding(.trailing, 12).frame(minHeight: 44)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .avoidingWindowControls()
    }

    private func playerDock(at now: Date, compact: Bool = false) -> some View {
        VStack(spacing: compact ? 12 : 16) {
            TableControls(session: session, table: table, now: now, raising: $raising,
                          reveal: privateHandHidden ? { revealedTurn = turnKey } : nil)
            HeroSeat(table: table, viewer: session.viewerID, profile: session.profile,
                     now: now, isLocal: session.isLocal, isRevealed: !privateHandHidden, isVisible: isPresented)
        }
    }

    private func playfield(at now: Date) -> some View {
        GeometryReader { geometry in
            ScrollView {
                if geometry.size.width >= 650 && geometry.size.width > geometry.size.height && !textSize.isAccessibilitySize {
                    VStack(spacing: 12) {
                        OpponentSeats(table: table, seats: opponents, now: now, isVisible: isPresented, compact: true)
                        HStack(alignment: .center, spacing: 24) {
                            Board(table: table).frame(maxWidth: .infinity)
                            playerDock(at: now, compact: true).frame(width: 300)
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 8)
                    .frame(minHeight: geometry.size.height)
                } else if textSize.isAccessibilitySize {
                    VStack(spacing: 24) {
                        Board(table: table)
                        playerDock(at: now)
                        OpponentSeats(table: table, seats: opponents, now: now, isVisible: isPresented)
                    }
                    .padding(20)
                } else {
                    VStack(spacing: 0) {
                        OpponentSeats(table: table, seats: opponents, now: now, isVisible: isPresented,
                                      singleRow: geometry.size.width >= 380 && textSize <= .xLarge)
                        Spacer(minLength: 16)
                        Board(table: table)
                        Spacer(minLength: 16)
                        playerDock(at: now)
                    }
                    .padding(20).frame(maxWidth: 640, minHeight: geometry.size.height)
                    .frame(maxWidth: .infinity)
                }
            }
            .clipped()
        }
    }
}

struct Board: View {
    let table: Poker.Table
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .body) private var scaledCardWidth: CGFloat = 60

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Group {
                if textSize.isAccessibilitySize {
                    let width = min(80, scaledCardWidth)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: width, maximum: width), spacing: 6)], spacing: 6) {
                        cards
                    }
                    .frame(maxWidth: width * 3 + 12)
                } else {
                    HStack(spacing: 6) { cards }
                        .aspectRatio(3.83, contentMode: .fit)
                }
            }
            .accessibilityElement(children: .contain).accessibilityIdentifier("table.board")
            .accessibilityLabel("Community cards")
            HStack(spacing: 8) {
                Text("Pot").foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(Chips.text(table.hand?.isComplete == true
                               ? table.awards.reduce(0) { $0 + $1.won } : table.hand?.pot ?? 0))
                    .fontWeight(.semibold).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
            .font(.subheadline)
            .accessibilityElement(children: .combine).accessibilityIdentifier("table.pot")
        }
        .frame(maxWidth: textSize.isAccessibilitySize ? .infinity : 420)
    }

    private var cards: some View {
        let board = table.hand?.board ?? []
        let winners = Set(table.awards.filter { $0.won > 0 }.flatMap { $0.hand?.cards ?? [] })
        return ForEach(0..<5, id: \.self) { index in
            let card = board.indices.contains(index) ? board[index] : nil
            PlayingCard(card: card, highlighted: card.map(winners.contains) == true)
                .accessibilityHidden(card == nil)
        }
    }
}

private struct HeroSeat: View {
    let table: Poker.Table
    let viewer: String
    let profile: Profile?
    let now: Date
    let isLocal: Bool
    let isRevealed: Bool
    let isVisible: Bool
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .body) private var scaledCardWidth: CGFloat = 60
    @ScaledMetric(relativeTo: .subheadline) private var lineHeight: CGFloat = 18

    private var showingCards: Bool {
        guard isRevealed else { return false }
        guard isLocal, let hand = table.hand, hand.isComplete else { return true }
        return table.stake(viewer)?.folded == false && hand.contenders.count > 1
    }

    var body: some View {
        let award = table.awards.first { $0.id == viewer && $0.won > 0 }
        let cards = showingCards ? table.hand?.cards(for: viewer) ?? [] : []
        let wager = award.map { "Won \(Chips.text($0.won))" }
            ?? table.stake(viewer).flatMap { $0.bet > 0 ? "Bet \(Chips.text($0.bet))" : nil }
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        layout {
            HStack(spacing: textSize.isAccessibilitySize ? 8 : -16) {
                ForEach(0..<2, id: \.self) { index in
                    let card = cards.indices.contains(index) ? cards[index] : nil
                    PlayingCard(card: card, highlighted: card.map { award?.hand?.cards.contains($0) == true } ?? false)
                }
            }
            .frame(width: textSize.isAccessibilitySize ? min(80, scaledCardWidth) * 2 + 8 : 152,
                   height: textSize.isAccessibilitySize ? min(80, scaledCardWidth) / 0.7 : 120)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(cards.isEmpty ? "" : "table.holeCards")
            .accessibilityLabel("Cards for \(table.seat(viewer)?.profile.name ?? "player")")
            .accessibilityHidden(cards.isEmpty)
            if let profile = table.seat(viewer)?.profile ?? profile {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name).fontWeight(.medium)
                        .lineLimit(textSize.isAccessibilitySize ? 2 : 1, reservesSpace: true)
                        .truncationMode(.middle)
                        .frame(height: lineHeight * (textSize.isAccessibilitySize ? 2 : 1))
                        .accessibilityIdentifier("table.hero.name")
                    HStack(spacing: 8) {
                        TurnAvatar(text: profile.avatar, hand: table.hand, duration: table.rules.turnSeconds,
                                   active: isVisible && table.hand?.turn == viewer, size: 32, now: now, dealer: table.hand?.dealerID == viewer)
                        Text(table.seat(viewer).map { Chips.text($0.chips) } ?? " ").monospacedDigit()
                            .font(.headline)
                            .lineLimit(1).minimumScaleFactor(0.5)
                            .accessibilityLabel(table.seat(viewer).map { "\(Chips.text($0.chips)) chips" } ?? "")
                            .accessibilityHidden(table.seat(viewer) == nil)
                            .accessibilityIdentifier("table.hero.stack")
                    }
                    .frame(height: max(32, lineHeight))
                    Text(handDescription).foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(height: lineHeight)
                        .accessibilityIdentifier("table.hero.hand")
                    Text(wager ?? " ").monospacedDigit().foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .frame(height: lineHeight)
                        .accessibilityLabel(wager.map { "\($0) chips" } ?? "")
                        .accessibilityHidden(wager == nil)
                }
                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain).accessibilityIdentifier("table.hero")
        .accessibilityValue(table.hand?.turn == viewer
                           ? "\(min(table.rules.turnSeconds, Int(ceil(table.hand?.remaining(at: now) ?? 0)))) seconds remaining" : "")
    }

    private var handDescription: String {
        guard isRevealed else { return "Hand hidden" }
        guard table.seat(viewer) != nil else { return "Not seated" }
        if table.stake(viewer)?.folded == true { return "Folded" }
        if table.seat(viewer)?.chips == 0 && table.hand?.isComplete == false { return "All in" }
        if showingCards, let hand = table.hand, !hand.cards(for: viewer).isEmpty,
           let value = HandValue.best(hand.cards(for: viewer) + hand.board) { return value.name }
        return table.hand?.isComplete == true ? "" : "Next hand"
    }
}

private struct OpponentSeats: View {
    let table: Poker.Table
    let seats: [Seat?]
    let now: Date
    let isVisible: Bool
    var compact = false
    var singleRow = false
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .body) private var scaledCardWidth: CGFloat = 60
    @ScaledMetric(relativeTo: .subheadline) private var lineHeight: CGFloat = 18
    private var portraitWidth: CGFloat {
        textSize.isAccessibilitySize ? min(80, scaledCardWidth) * 2 + 3 : 64
    }
    private var seatHeight: CGFloat {
        let details = lineHeight * (textSize.isAccessibilitySize ? 5 : 4) + 8
        return compact ? max(portraitWidth / 1.45, details) : portraitWidth / 1.45 + 6 + details
    }

    var body: some View {
        // Settlement ranks every hand; evaluate it once for the whole grid.
        let awards = table.awards
        let wideAmounts = table.rules.buyIn * table.rules.capacity >= 1_000_000
        let columns = textSize.isAccessibilitySize ? 1 : (compact || singleRow) && !wideAmounts ? 5 : 3
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top), count: max(1, columns)),
                  alignment: .center, spacing: 20) {
            let count = textSize.isAccessibilitySize ? (seats.lastIndex { $0 != nil }.map { $0 + 1 } ?? 0) : seats.count
            ForEach(0..<count, id: \.self) { index in
                if let seat = seats[index] {
                    opponent(seat, result: awards.first { $0.id == seat.id })
                } else {
                    Color.clear.frame(height: seatHeight).accessibilityHidden(true)
                }
            }
        }
    }

    private func opponent(_ seat: Seat, result: Award?) -> some View {
        let stake = table.stake(seat.id)
        let award = result.flatMap { $0.won > 0 ? $0 : nil }
        let status: String = if let award { "Won \(Chips.text(award.won))" }
            else if seat.hasLeft { "Left" }
            else if stake?.folded == true { "Folded" }
            else if let hand = result?.hand { hand.name }
            else if seat.chips == 0 && table.hand?.isComplete == false { "All in" }
            else if stake?.lastAction == .call { "Call" }
            else if let stake, stake.bet > 0 { "Bet \(Chips.text(stake.bet))" }
            else { stake?.lastAction?.name ?? " " }
        let spokenStatus = if award == nil { status }
            else if let hand = award?.hand { "\(status) chips, \(hand.name)" }
            else { "\(status) chips" }
        let showingCards = isVisible && table.hand?.isComplete == true && stake?.folded == false && (table.hand?.contenders.count ?? 0) > 1
        let identity = compact
            ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 6))
        return identity {
            ZStack {
                Color.clear
                if let hand = table.hand, showingCards {
                    let winning = award?.hand?.cards ?? []
                    HStack(spacing: 3) {
                        ForEach(hand.cards(for: seat.id)) { PlayingCard(card: $0, highlighted: winning.contains($0)) }
                    }
                } else {
                    TurnAvatar(text: seat.profile.avatar, hand: table.hand, duration: table.rules.turnSeconds,
                               active: isVisible && table.hand?.turn == seat.id, size: 44, now: now)
                }
            }
            .aspectRatio(1.45, contentMode: .fit).frame(maxWidth: portraitWidth)
            .frame(width: compact ? portraitWidth : nil)
            .opacity(stake?.folded == true ? 0.4 : 1)
            .overlay(alignment: .bottomTrailing) {
                if table.hand?.dealerID == seat.id { DealerMark() }
            }
            VStack(alignment: compact ? .leading : .center, spacing: 4) {
                Text(seat.profile.name).fontWeight(.medium)
                    .lineLimit(textSize.isAccessibilitySize ? 2 : 1, reservesSpace: true)
                    .truncationMode(.middle)
                    .frame(height: lineHeight * (textSize.isAccessibilitySize ? 2 : 1))
                Text(Chips.text(seat.chips))
                    .monospacedDigit().foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: lineHeight)
                Text(status)
                    .monospacedDigit().foregroundStyle(.white.opacity(award == nil ? 0.65 : 1))
                    .lineLimit(2, reservesSpace: true).minimumScaleFactor(0.8)
                    .multilineTextAlignment(compact ? .leading : .center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: lineHeight * 2)
                    .accessibilityLabel(spokenStatus)
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: compact ? .leading : .center)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("table.opponent.\(seat.id)")
        .accessibilityValue(table.hand?.turn == seat.id
                           ? "\(min(table.rules.turnSeconds, Int(ceil(table.hand?.remaining(at: now) ?? 0)))) seconds remaining" : "")
    }
}

private struct DealerMark: View {
    var body: some View {
        Text("D").font(.system(size: 10, weight: .bold))
            .frame(width: 16, height: 16).background(.white, in: Circle()).foregroundStyle(RiverStyle.ink)
            .overlay(Circle().strokeBorder(RiverStyle.ink, lineWidth: 1))
            .accessibilityLabel("Dealer")
    }
}

struct TurnAvatar: View {
    let text: String
    let hand: Hand?
    let duration: Int
    let active: Bool
    let size: CGFloat
    let now: Date
    var dealer = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Avatar(text: text, size: size)
            .overlay {
                if active, let hand, !hand.isComplete, hand.remaining(at: now) > 0 {
                    TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30)) { clock in
                        Circle().trim(from: 0, to: min(1, hand.remaining(at: clock.date) / Double(duration)))
                            .stroke(
                                hand.remaining(at: clock.date) <= 5 ? Color.orange : Color.mint,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90)).padding(-4)
                    }
                    .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if dealer { DealerMark() }
            }
    }
}
