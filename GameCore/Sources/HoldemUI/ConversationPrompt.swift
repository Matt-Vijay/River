import SwiftUI

struct ConversationPrompt<Accessory: View>: View {
    enum Icon {
        case text(String)
        case system(String)
    }

    let icon: Icon
    let title: String
    let message: String
    var spacing: CGFloat = 20
    @ViewBuilder var accessory: Accessory

    var body: some View {
        ScrollView {
            VStack(spacing: spacing) {
                iconView
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .allowsTightening(true)
                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                accessory
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 36)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .text(let text):
            Text(text)
                .font(.system(size: 64))
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
        }
    }
}
