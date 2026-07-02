import SwiftUI

struct DemoGameTable: View {
    let controller: GameController
    @State private var fly: WinningsFly?

    var body: some View {
        PokerTableView(
            state: controller.state, heroID: controller.heroID,
            onAction: { controller.act($0) },
            onDealNext: { controller.dealNextHand() },
            onLeave: { controller.leave(id: controller.heroID) }
        )
        .transition(.opacity)
        .overlay {
            if let fly { WinningsFlyView(fly: fly).id(fly.id) }
        }
        .onChange(of: controller.handOver) { _, isOver in
            guard isOver,
                  let winner = controller.state.results?
                    .filter({ $0.amountWon > 0 })
                    .max(by: { $0.amountWon < $1.amountWon }) else { return }
            fly = WinningsFly(amount: winner.amountWon,
                              toHero: winner.playerID == controller.heroID,
                              id: controller.state.handNumber)
        }
    }
}
