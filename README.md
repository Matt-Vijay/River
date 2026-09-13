# River

Native Texas Hold'em, played in a Messages conversation or around one iPhone.

## Product Contract

- A locally saved name and character come before table actions.
- A Messages invitation is the table itself, not a link to an onboarding flow.
- Opening a table claims a seat, for the next hand if play is already underway.
  Receiving an update never claims a seat.
- Two to six people play no-limit Hold'em with play chips, 5/10 blinds, and a
  30-second turn. Starting remains visible and disabled until two people sit.
- Calls, full and short all-in raises, side pots, tied hands, refunds, folding,
  departures, next-hand joins, and button rotation follow the game rules.
- A player can resolve an expired turn: check when free, otherwise fold.
- Standalone play hides each hand until its player reveals it, including after
  backgrounding. Messages shows only the local player's private cards.
- A failed or stale send cannot silently overwrite a newer accepted table.

## Design

The table is the product. There is no dashboard, currency store, account system,
engagement loop, ornamental glass, or tutorial masquerading as an interface.
Dark neutral surfaces are the only theme; suits, characters, and the turn timer
use selective color accents. Native typography and controls, actual playing
cards, clear positions, and one primary action establish hierarchy. Contrast,
suit shapes, and text communicate state without relying on color. Large text and
VoiceOver are first-class; the turn clock remains continuous.

## Architecture

- `RiverKit/Sources/Poker`: value-state rules and the bounded message codec.
  A hand stores one immutable deck; hole cards and board derive from deal order.
  All changes pass through one transactional operation function.
- `RiverKit/Sources/RiverUI`: the shared native screens and local profile store.
- `App`: standalone session ownership and the app entry point.
- `Messages`: the Messages host adapter and send/receive lifecycle.
- `Tests`: a few end-to-end app and Messages checks. Domain tests live beside
  their package, independent of UI implementation details.

Messages is the transport and history, with no backend or analytics. Participant
UUIDs are device-local; sender-to-seat bindings are trust-on-first-use. Encoded
state contains the deck. This is private, casual honest-client play, not a
cryptographically secure gambling platform.

The previous checksummed message format is imported in one direction. Existing
cards, stacks, turn deadlines, and saved sender bindings are preserved; the next
action writes the new format. Everyone at a continuing table must update River.
Older unchecksummed messages are not playable. The compatibility fixture comes
from the preserved implementation, not a second rules engine.

## Development

Build with Xcode 26+ in Swift 6 language mode; the app still targets iOS 17+.
Open `River.xcodeproj` normally; `project.yml` is the small source of truth for
regenerating it with XcodeGen. No runtime dependencies.

```sh
swift test --package-path RiverKit
xcodegen generate
xcodebuild -project River.xcodeproj -scheme River \
  -destination 'platform=iOS Simulator,name=Poker iPhone 16' build
```

Bundle identifiers and app group are unchanged. Device distribution requires
an Apple developer team and the `group.com.dewylabs.river` capability.
Real recipient delivery requires two signed-in devices; simulator checks alone
do not establish it.
After reinstalling in Simulator, relaunch Messages if the extension opens blank;
its running host can retain an obsolete plug-in registration.

For local five-player delivery simulation using the same rules, wire codec,
history, and SwiftUI screens, see [River Local](Simulation/README.md). It is a
separate development executable and simulator app, not a shipping feature.

## Verification

The focused domain suite covers hand ranking, blind and raise boundaries,
side-pot winners and odd chips, departures and timeouts, deterministic replay,
bounded decoding, sender bindings, and legacy import. Three UI checks cover
profile persistence and a complete hand, six-seat rotation and background
privacy, and the real Messages host's send/open/cancel/leave/rejoin flow.
The Messages check launches River first so XCTest installs the current embedded
extension; launching only Messages can exercise a previously installed build.
Hands-on simulator review supplements those checks for dark mode, maximum
accessibility text, safe areas, and the invitation artwork.

Simulator Messages stages outgoing updates in its composer; its synthetic
conversation is not evidence of delivery to another Apple account. No backend,
real-money play, telemetry, or cryptographic card secrecy is introduced.
