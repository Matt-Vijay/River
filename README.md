# River

River is native Texas Hold'em for iMessage. Each action sends the next encoded
table state, making the conversation both transport and history. The same app
also provides standalone pass-and-play for local gameplay and UI iteration.

## Architecture

- `GameCore/Sources/GameCore`: poker rules, state transitions, message payloads, revisions, and operation validation. This layer has no UI dependency.
- `GameCore/Sources/HoldemUI`: shared SwiftUI screens and presentation logic used by both app surfaces.
- `MessagesExtension`: the iMessage lifecycle, selected-message rendering, local profile state, and asynchronous message transport.
- `River`: the containing iOS app. It hosts standalone play and embeds the Messages extension.
- `RiverUITests`: focused interactions for both the standalone app and the real Messages host.

## Requirements

- Xcode 16 or newer (Swift 6 language mode throughout)
- iOS 17 or newer

## Build

```sh
xcodebuild \
  -project River.xcodeproj \
  -scheme River \
  -destination 'platform=iOS Simulator,name=Poker iPhone 16' \
  build
```

For device or TestFlight builds, select your Apple developer team with automatic
signing and register `group.com.dewylabs.river` for the app
(`com.dewylabs.river`) and Messages extension (`com.dewylabs.river.messages`).

## Test

Run the deterministic rules and SwiftUI contract suite:

```sh
swift test --package-path GameCore
```

Run standalone gameplay interactions only:

```sh
xcodebuild \
  -project River.xcodeproj \
  -scheme River \
  -destination 'platform=iOS Simulator,name=Poker iPhone 16' \
  -only-testing:RiverUITests/RiverInteractionTests \
  test
```

Run real Messages-host interactions:

Use a simulator with the synthetic `+1 (888) 555-1212` conversation. The test
intentionally refuses to select other recipients.

```sh
xcodebuild \
  -project River.xcodeproj \
  -scheme River \
  -destination 'platform=iOS Simulator,name=Poker iPhone 16' \
  -only-testing:RiverUITests/RiverMessagesInteractionTests \
  test
```

Simulator validates extension discovery, profile persistence, and sender-side
send/open/leave/rejoin. Recipient delivery still requires two signed-in devices.

## Product Contract

- Players configure and locally save their handle and avatar before opening a table.
- Opening a lobby invitation seats the player; merely receiving an update never sends an action.
- Participant identity comes from Messages; players never relabel themselves inside a lobby.
- Messages participant IDs are device-local. Each device persists sender-to-seat
  bindings on first contact and rejects later identity changes or seat collisions.
  This is an honest-client, trust-on-first-use game, not cryptographic anti-cheat;
  the encoded state also contains the undealt deck and hole cards.
- Every mutation is validated against table identity, phase, revision, actor, and legal state.
- Successful sends and accepted incoming states advance the remembered revision;
  optimistic or failed sends do not.
- Invalid, stale, rejected, and failed updates produce an explicit recovery screen.
