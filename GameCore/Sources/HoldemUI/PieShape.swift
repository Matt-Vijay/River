import SwiftUI

/// A filled pie wedge representing `fraction` (1 = full circle) starting at 12
/// o'clock and sweeping clockwise.
struct PieShape: Shape {
    var fraction: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        guard fraction > 0 else { return path }
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * min(1, fraction)),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
