# River Local

Development-only, five-client multiplayer simulation. Nothing in this directory
is linked into the shipping River app or Messages extension.

Each player has a separate profile, `RiverSession`, `TableHistory`, persisted
UserDefaults suite, inbox, and device-local sender aliases. The local transport
passes the real compressed `TableMessage` URL, never a shared `Table` object.
The simulator app renders the existing `RiverRoot` for the selected player.
Automatic players choose from their own legal bets, without inspecting other
players' cards. No backend, account, network listener, or dependency is added.

## Reproducible Run

From the project root:

```sh
swift run --package-path Simulation RiverSimulation /tmp/river-five-player.json
```

This runs three deterministic seeds. Each run exercises nine hands, simultaneous
joins and recovery, late join/leave/rejoin, a disconnected client and failed send,
duplicates, stale and malformed input, sender impersonation, reverse-order
reconnection, a process-state reconstruction, offline-player timeout resolution,
and final unequal-stack all-ins. During five-player play, each drained round checks all five fingerprints, state
validation, viewer identity, and conservation of 5,000 play chips.

The JSON records actual serialized packets, delivery events, each client's
revision/fingerprint, scenario checks, and five final tables. Failure exits
nonzero. Temporary client stores are removed at the end of each run.

## Interactive iPhone Simulator

```sh
xcodegen generate --spec Simulation/project.yml
open Simulation/RiverSimulation.xcodeproj
```

Run `RiverSimulation` on **Poker iPhone 16**, not Dewy's iPhone 17. The installed
app is **River Local** (`com.dewylabs.river.simulation`), separate from River.
Play exchanges one delivery or action per step; Pause and Step allow inspection
between deliveries. Pause stops the driver, not the real game clock. The five
player selectors switch real player views. You can
also operate the normal game controls yourself, disconnect/reconnect a player,
reopen its table, reconstruct its session from storage, and inspect the event log.
The interactive app retains the latest 512 message and event records; pending
deliveries are never trimmed. CLI reports retain the full trace.
Launch and Reset start fresh using the same five stores; Restart player preserves
that player's current-run history. CLI runs retain independent temporary stores.

The production-only change needed for isolation is an injectable UserDefaults
argument in `RiverSession`; its normal app-group default is unchanged.

## Boundary

These are five isolated clients in one local process, not five Apple devices.
This verifies River's rules, wire format, sender history, convergence, and shared
UI under a controlled transport. It does **not** establish Apple Messages network
delivery, extension activation/callback ordering, entitlements, or account routing.
Those remain real-device checks. A deterministic concurrent-join loser reopens
the table to recover its seat; this harness does not hide that behavior by merging
branches or silently adding retries that the app does not have.
