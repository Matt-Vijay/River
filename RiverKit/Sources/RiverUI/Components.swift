import SwiftUI
import Poker

enum RiverStyle {
    static let ink = Color(white: 0.06)
    static let felt = Color(white: 0.10)
}

extension View {
    // Scroll content clears corner insets; apply this to headers outside the scroll view.
    @ViewBuilder func avoidingWindowControls() -> some View {
        if #available(iOS 26, macOS 26, *) {
            containerCornerOffset(.horizontal, sizeToFit: true)
        } else {
            self
        }
    }
}

private struct ChipMark: View {
    var body: some View {
        Canvas { context, size in
            let width = min(size.width, size.height)
            let rect = CGRect(x: (size.width - width) / 2, y: (size.height - width) / 2, width: width, height: width)
            context.fill(Path(ellipseIn: rect), with: .color(.white))
            context.stroke(Path(ellipseIn: rect.insetBy(dx: width * 0.035, dy: width * 0.035)),
                           with: .color(.black), lineWidth: width * 0.07)
            context.stroke(Path(ellipseIn: rect.insetBy(dx: width * 0.22, dy: width * 0.22)),
                           with: .color(.black), lineWidth: width * 0.035)
            for index in 0..<8 {
                var edge = context
                edge.translateBy(x: size.width / 2, y: size.height / 2)
                edge.rotate(by: .degrees(Double(index) * 45))
                edge.fill(Path(CGRect(x: -width * 0.05, y: -width * 0.45, width: width * 0.1, height: width * 0.18)),
                          with: .color(.black))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct Brand: View {
    var body: some View {
        HStack(spacing: 9) {
            ChipMark().frame(width: 27, height: 27)
            Text("River").font(.title3.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }
}

struct ActionButton: View {
    let title: String
    var id: String = ""
    var isEnabled = true
    var prominent = true
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(RiverButtonStyle(prominent: prominent))
            .disabled(!isEnabled)
            .accessibilityIdentifier(id)
    }
}

struct RiverButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline).multilineTextAlignment(.center)
            .foregroundStyle(isEnabled && prominent ? RiverStyle.ink : Color.white.opacity(isEnabled ? 1 : 0.45))
            .padding(.horizontal, 12).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(isEnabled && prominent ? Color.white : Color.white.opacity(configuration.isPressed ? 0.16 : 0.08),
                        in: RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed && prominent ? 0.8 : 1)
    }
}

struct Avatar: View {
    let text: String
    var size: CGFloat = 44

    var body: some View {
        Text(text).font(.system(size: size * 0.6))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct PlayingCard: View {
    let card: Card?
    var winning: Bool? = nil

    var body: some View {
        GeometryReader { geometry in
            let small = geometry.size.width < 45
            let large = geometry.size.width > 68
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(card == nil ? Color(white: 0.16) : .white)
                if let card {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(card.label).font(.system(size: small ? 15 : large ? 32 : 24, weight: .semibold, design: .rounded))
                        if !small { Spacer(minLength: 0) }
                        Text(card.suit.symbol).font(.system(size: small ? 12 : large ? 26 : 19))
                        if small { Spacer(minLength: 0) }
                    }
                    .foregroundStyle(card.suit.isRed
                        ? Color(red: 0.72, green: 0.08, blue: 0.16) : RiverStyle.ink)
                    .padding(small ? 4 : 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(card == nil ? .white.opacity(0.25) : .black.opacity(0.14), lineWidth: 1)
            }
        }
        .aspectRatio(0.7, contentMode: .fit)
        .colorMultiply(winning == false ? Color(white: 0.65) : .white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((card?.spoken ?? "Face-down card") + (winning == true ? ", Winning hand" : ""))
    }
}

struct LeaveButton: View {
    let session: RiverSession
    let table: Poker.Table
    @State private var confirming = false

    var body: some View {
        let viewer = session.viewerID
        let seat = table.seat(viewer)
        let inHand = table.hand?.isComplete == false && table.stake(viewer)?.folded == false
        let title = inHand ? (seat?.chips == 0 ? "Leave? You stay all in." : "Fold and leave?") : "Leave table?"
        Button { confirming = true } label: {
            Image(systemName: "rectangle.portrait.and.arrow.right").font(.body.weight(.medium))
            .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .accessibilityLabel("Leave table")
        .buttonStyle(.plain)
        .accessibilityIdentifier("table.leave")
        .alert(title, isPresented: $confirming) {
            Button("Leave", role: .destructive) {
                // Native alerts retain their action closure while unrelated updates arrive.
                guard session.isVisible, !session.isCompact, let latest = session.table, latest.id == table.id,
                      session.viewerID == viewer, latest.hand?.number == table.hand?.number,
                      latest.seat(viewer)?.hasLeft == false else { return }
                session.act(.leave, on: latest)
            }.accessibilityIdentifier("table.leave.confirm")
            Button("Stay", role: .cancel) {}.accessibilityIdentifier("table.leave.cancel")
        }
        .onChange(of: table.hand?.number) { confirming = false }
        .onChange(of: viewer) { confirming = false }
        .onChange(of: session.isVisible) { if !session.isVisible { confirming = false } }
        .onChange(of: session.isCompact) { if session.isCompact { confirming = false } }
    }
}
