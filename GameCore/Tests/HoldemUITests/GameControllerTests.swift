import Foundation
import Testing
import GameCore
import HoldemUI

@Suite("Game controller")
struct GameControllerTests {
    private final class Clock: @unchecked Sendable {
        var dates: [Date]

        init(_ dates: [Date]) {
            self.dates = dates
        }

        func now() -> Date {
            dates.removeFirst()
        }
    }

    @MainActor
    @Test("controller starts from the injected seed and clock")
    func startUsesEnvironment() {
        let now = Date(timeIntervalSince1970: 12_345)
        let lobby = Lobby()
            .adding(id: "a", name: "Alice", avatar: "A")
            .adding(id: "b", name: "Bob", avatar: "B")

        let environment = GameControllerEnvironment(
            makeSeed: { 42 },
            now: { now }
        )

        let controller = GameController(lobby: lobby, environment: environment)

        #expect(controller.state == lobby.start(seed: 42, now: now))
    }

    @MainActor
    @Test("controller actions use the injected clock")
    func actionsUseEnvironmentClock() {
        let startTime = Date(timeIntervalSince1970: 12_345)
        let actionTime = Date(timeIntervalSince1970: 67_890)
        let clock = Clock([startTime, actionTime])
        let lobby = Lobby()
            .adding(id: "a", name: "Alice", avatar: "A")
            .adding(id: "b", name: "Bob", avatar: "B")
            .adding(id: "c", name: "Cara", avatar: "C")

        let environment = GameControllerEnvironment(
            makeSeed: { 42 },
            now: { clock.now() }
        )

        let controller = GameController(lobby: lobby, environment: environment)

        controller.act(.call)

        #expect(controller.state.turnStartedAt == actionTime)
    }

    @MainActor
    @Test("controller supports raise call and check interaction flow")
    func controllerSupportsRaiseCallAndCheckFlow() {
        let clock = Clock([
            Date(timeIntervalSince1970: 1),
            Date(timeIntervalSince1970: 2),
            Date(timeIntervalSince1970: 3),
            Date(timeIntervalSince1970: 4),
        ])
        let lobby = Lobby()
            .adding(id: "a", name: "Alice", avatar: "A")
            .adding(id: "b", name: "Bob", avatar: "B")
        let controller = GameController(
            lobby: lobby,
            environment: GameControllerEnvironment(makeSeed: { 1 }, now: { clock.now() })
        )

        controller.act(.raise(to: 20))
        #expect(controller.state.players[0].lastAction == .raise(to: 20))

        controller.act(.call)
        #expect(controller.state.street == .flop)

        controller.act(.check)
        #expect(controller.state.players.contains { $0.lastAction == .check })
    }

    @MainActor
    @Test("controller supports fold interaction")
    func controllerSupportsFoldInteraction() {
        let lobby = Lobby()
            .adding(id: "a", name: "Alice", avatar: "A")
            .adding(id: "b", name: "Bob", avatar: "B")
        let controller = GameController(
            lobby: lobby,
            environment: GameControllerEnvironment(makeSeed: { 1 }, now: { Date(timeIntervalSince1970: 1) })
        )

        let foldingHero = controller.heroID
        controller.act(.fold)

        #expect(controller.state.player(id: foldingHero)?.status == .folded)
        #expect(controller.handOver)
    }

    @MainActor
    @Test("controller supports leave interaction")
    func controllerSupportsLeaveInteraction() {
        let lobby = Lobby()
            .adding(id: "a", name: "Alice", avatar: "A")
            .adding(id: "b", name: "Bob", avatar: "B")
            .adding(id: "c", name: "Cara", avatar: "C")
        let controller = GameController(
            lobby: lobby,
            environment: GameControllerEnvironment(makeSeed: { 1 }, now: { Date(timeIntervalSince1970: 1) })
        )

        let leavingHero = controller.heroID
        controller.leave(id: leavingHero)

        #expect(controller.state.player(id: leavingHero)?.hasLeft == true)
    }

    @MainActor
    @Test("controller supports manual deal next hand interaction after a fold")
    func controllerSupportsManualDealNextHandInteraction() {
        let clock = Clock([
            Date(timeIntervalSince1970: 1),
            Date(timeIntervalSince1970: 2),
            Date(timeIntervalSince1970: 3),
        ])
        let lobby = Lobby()
            .adding(id: "a", name: "Alice", avatar: "A")
            .adding(id: "b", name: "Bob", avatar: "B")
        let controller = GameController(
            lobby: lobby,
            environment: GameControllerEnvironment(makeSeed: { 1 }, now: { clock.now() })
        )

        controller.act(.fold)
        let completedHand = controller.state.handNumber
        controller.dealNextHand()

        #expect(controller.state.handNumber == completedHand + 1)
        #expect(!controller.handOver)
    }

    @MainActor
    @Test("controller keeps completed hands visible until explicit deal next")
    func controllerKeepsCompletedHandsVisibleUntilExplicitDealNext() async throws {
        let lobby = Lobby()
            .adding(id: "a", name: "Alice", avatar: "A")
            .adding(id: "b", name: "Bob", avatar: "B")
        let controller = GameController(
            lobby: lobby,
            environment: GameControllerEnvironment(makeSeed: { 1 }, now: { Date(timeIntervalSince1970: 1) })
        )

        controller.act(.fold)
        let completedHand = controller.state.handNumber

        try await Task.sleep(for: .milliseconds(3_200))

        #expect(controller.state.handNumber == completedHand)
        #expect(controller.handOver)
    }
}
