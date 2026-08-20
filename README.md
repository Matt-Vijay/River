# River

River is native Texas Hold'em for iMessage. A table is created and played inside a Messages conversation; each action produces the next encoded table message, so the chat transcript is the multiplayer transport and history.

The repository also includes a standalone pass-and-play app for fast UI iteration and deterministic gameplay testing.

## Architecture

- `GameCore/Sources/GameCore`: poker rules, state transitions, message payloads, revisions, and operation validation. This layer has no UI dependency.
- `GameCore/Sources/HoldemUI`: shared SwiftUI screens and presentation logic used by both app surfaces.
- `MessagesExtension`: the iMessage lifecycle, selected-message rendering, local profile state, and asynchronous message transport.
- `River`: the standalone UI and gameplay harness.
- `RiverUITests`: end-to-end standalone gameplay interactions.
- `RiverMessagesInteractionTests`: end-to-end interactions hosted by the real Messages app.

`project.yml` is the source of truth for the generated Xcode project.

## Requirements

- Xcode 16 or newer
- iOS 17 or newer
- XcodeGen

## Generate And Build

```sh
xcodegen generate
xcodebuild \
  -project River.xcodeproj \
  -scheme RiverMessages \
  -destination 'platform=iOS Simulator,name=Poker iPhone 16' \
  build
```

The `RiverMessages` container is intentionally launch-prohibited and does not appear on the Home Screen. Open River from the Messages app drawer.

For device or TestFlight builds, select your Apple developer team with automatic
signing and register `group.com.dewylabs.river` for both the standalone app and
Messages extension. `RiverMessages` (`com.dewylabs.river`) is the shipping target;
`River` (`com.dewylabs.river.standalone`) is the local pass-and-play harness.

## Test

Run the deterministic rules and SwiftUI contract suite:

```sh
swift test --package-path GameCore
```

Run standalone gameplay interactions:

```sh
xcodebuild \
  -project River.xcodeproj \
  -scheme River \
  -destination 'platform=iOS Simulator,name=Poker iPhone 16' \
  test
```

Run real Messages-host interactions:

```sh
./scripts/test-messages.sh
```

The script uses the `Poker iPhone 16` simulator by default. Override it with
`RIVER_SIMULATOR_UDID` or `RIVER_SIMULATOR_NAME`. It builds the test products,
reinstalls that exact `RiverMessages` build, then runs the MobileSMS-hosted tests
without rebuilding. This prevents Messages from exercising a stale installed
extension.

Simulator validates extension discovery, profile persistence, and table creation
on the sender side. Its fake conversations can stage a successful direct send in
the host composer, so the integration test completes that simulator-only host
step. Recipient selection and remote delivery require two signed-in devices.

## Product Contract

- Players configure and locally save their handle and avatar before opening a table.
- Opening a lobby invitation seats the player; merely receiving an update never sends an action.
- Participant identity comes from Messages; players never relabel themselves inside a lobby.
- Every mutation is validated against table identity, phase, revision, actor, and legal state.
- Only successful sends advance the locally remembered revision.
- Invalid, stale, rejected, and failed updates produce an explicit recovery screen.
