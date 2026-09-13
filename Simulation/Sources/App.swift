import Foundation

#if os(iOS)
import SwiftUI
import RiverUI

@main struct SimulationApp: App {
    @State private var simulation = LocalSimulation(run: "interactive", traceLimit: 512)

    var body: some Scene {
        WindowGroup {
            SimulationView(simulation: simulation) {
                simulation.cleanup()
                simulation = LocalSimulation(run: "interactive", traceLimit: 512)
            }
        }
    }
}

private struct SimulationView: View {
    @Bindable var simulation: LocalSimulation
    let reset: () -> Void
    @State private var showingLog = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Player", selection: $simulation.selected) {
                    ForEach(simulation.players) { player in
                        Text(player.name + (player.online ? "" : " (offline)")).tag(player.index)
                    }
                }
                .pickerStyle(.menu).labelsHidden().fixedSize()
                Spacer()
                Button {
                    simulation.playing.toggle()
                } label: {
                    Image(systemName: simulation.playing ? "pause.fill" : "play.fill").frame(width: 44, height: 44)
                }.accessibilityLabel(simulation.playing ? "Pause" : "Play")
                Menu {
                    Text(simulation.synchronized ? "5 in sync" : "\(simulation.queue.count) queued")
                    Button("Step", systemImage: "forward.end.fill") { simulation.attempt { try simulation.advance() } }
                    Button("Open table", systemImage: "envelope.open") { simulation.attempt { try simulation.open(simulation.selected) } }
                    Button(simulation.selectedPlayer.online ? "Disconnect player" : "Reconnect player", systemImage: "wifi.slash") {
                        simulation.selectedPlayer.online.toggle()
                    }
                    Button("Restart player", systemImage: "arrow.clockwise") {
                        simulation.attempt { try simulation.restart(simulation.selected) }
                    }
                    Button("Event log", systemImage: "list.bullet.rectangle") { showingLog = true }
                    Divider()
                    Button("Reset simulation", systemImage: "arrow.counterclockwise", action: reset)
                } label: { Label("Simulation controls", systemImage: "ellipsis.circle").frame(width: 44, height: 44) }
                .labelStyle(.iconOnly)
            }
            .font(.body)
            .buttonStyle(.plain)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .padding(.horizontal, 16).padding(.vertical, 8).background(.background)
            Divider()
            RiverRoot(session: simulation.selectedPlayer.session).id(simulation.selectedPlayer.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .tint(.white)
        .task(id: simulation.playing) {
            while simulation.playing && !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                guard simulation.playing && !Task.isCancelled else { return }
                simulation.attempt { try simulation.advance() }
            }
        }
        .sheet(isPresented: $showingLog) {
            NavigationStack {
                List(simulation.events.reversed(), id: \.number) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.description).font(.subheadline)
                        Text("#\(event.number) | \(event.revisions.map { $0.map(String.init) ?? "-" }.joined(separator: " / "))")
                            .font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Local message log")
                .toolbar { Button("Done") { showingLog = false } }
            }
        }
    }
}
#else
@main enum SimulationRunner {
    @MainActor static func main() throws {
        var reports: [LocalSimulation.Report] = []
        for seed: UInt64 in [7, 42, 2026] {
            let simulation = LocalSimulation(seed: seed, clock: Date(timeIntervalSince1970: 1_800_000_000))
            defer { simulation.cleanup() }
            reports.append(try simulation.exercise())
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let path = CommandLine.arguments.dropFirst().first {
            try encoder.encode(reports).write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        for report in reports {
            print("PASS seed \(report.seed): \(report.hands) hands, \(report.packets.count) sent messages, \(report.events.count) events, \(report.checks.count) checks")
        }
    }
}
#endif
