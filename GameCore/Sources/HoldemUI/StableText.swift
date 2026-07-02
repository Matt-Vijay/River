import SwiftUI

extension View {
    func stableOneLineText(minScale: CGFloat = 0.82) -> some View {
        lineLimit(1)
            .minimumScaleFactor(minScale)
            .allowsTightening(true)
    }
}
