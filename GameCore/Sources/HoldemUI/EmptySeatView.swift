import SwiftUI

/// Empty seat placeholder ("+") shown for open spots at the table.
public struct EmptySeatView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 4) {
            Color.clear.frame(height: 18)
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 58, height: 58)
                .overlay(Circle().strokeBorder(Theme.controlStroke, lineWidth: 1.5))
        }
        .frame(width: 76)
    }
}
