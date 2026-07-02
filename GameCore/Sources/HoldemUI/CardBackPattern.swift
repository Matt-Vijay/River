import SwiftUI

/// Diagonal hatch pattern for the card back.
struct HatchBack: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 9
            let path = Path { path in
                var x = -size.height
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    x += spacing
                }
            }
            context.stroke(path, with: .color(Theme.hatch), lineWidth: 2.5)
        }
    }
}
