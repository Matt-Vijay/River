import Foundation
import HoldemUI

// Renders PokerTableView to PNGs off-screen so the layout can be inspected
// without a simulator.
@main
struct RenderTableMain {
    static func main() async {
        await MainActor.run {
            let writer = PNGWriter()

            let (acting, actingHero) = RenderScenarios.actingState()
            writer.writePNG(PokerTableView(state: acting, heroID: actingHero), to: "acting.png")

            let (waiting, waitingHero) = RenderScenarios.waitingState()
            writer.writePNG(PokerTableView(state: waiting, heroID: waitingHero), to: "waiting.png")

            // Hero mid-turn: shows the depleting box border partway through.
            var (timed, timedHero) = RenderScenarios.actingState()
            timed.turnStartedAt = Date().addingTimeInterval(-13)  // ~57% of 30s left
            writer.writePNG(PokerTableView(state: timed, heroID: timedHero), to: "herotimer.png")

            // Hero is the big blind (has a bet) but not to act: bet chip should
            // sit centred above the action area.
            let heroBet = RenderScenarios.heroBetState()
            writer.writePNG(PokerTableView(state: heroBet, heroID: "dante"), to: "herobet.png")

            let (showdown, showdownHero) = RenderScenarios.showdownState()
            writer.writePNG(PokerTableView(state: showdown, heroID: showdownHero, onDealNext: {}), to: "showdown.png")

            // 6-player table: 5 opponents must fit without overflow.
            let (six, sixHero) = RenderScenarios.sixPlayerState()
            writer.writePNG(PokerTableView(state: six, heroID: sixHero, onLeave: {}), to: "six.png")

            writer.writePNG(ProfileSetupView(onSave: { _, _ in }), to: "profile.png")

            writer.writePNG(LobbyView(lobby: RenderScenarios.lobby(), localID: "you",
                                      onJoin: {}, onToggleReady: {}), to: "lobby.png")

            writer.writeSized(IconView(), width: 1024, height: 1024, to: "icon_1024.png")
            writer.writeSized(IconView(), width: 1024, height: 768, to: "icon_768.png")
            writer.writePNG(seatRow(), width: 600, height: 150, scale: 2, to: "seatrow.png")
        }
    }
}
