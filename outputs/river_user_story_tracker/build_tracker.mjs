import fs from "node:fs/promises";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outputDir = "/Users/matthew/Developer/River/outputs/river_user_story_tracker";
const xlsxPath = `${outputDir}/river_user_story_tracker.xlsx`;

const stories = [
  ["HM-001", "Profile", "First-run profile setup", "As a new player, I configure my handle and avatar before seeing any join/start action.", "If no saved profile exists, the app renders a compact ProfileSetupView with one title, avatar picker, labelled handle field, and bottom save action. Save is disabled until the trimmed handle is non-empty. Saving normalizes name/avatar and moves to lobby/start flow.", "profile.name, profile.save, profile.avatar.N", "River.swift; GameTableScreen.swift; ProfileSetupView.swift; ProfileStore.swift; ProfileText.swift", "ProfileStoreTests; FrontendInteractionContractTests", "Needs manual test", "Not run", "", "Critical", "Retain exploratory first-run visual pass; whitespace-only rejection, empty save gate, max length, avatar tap, save, and persistence are covered on Poker iPhone 16"],
  ["HM-002", "Profile", "Edit saved profile before joining", "As a returning player, I can edit my locally saved profile before taking a lobby or in-progress-game seat.", "Lobby/Join prompts show the saved profile summary with a compact pencil edit action. Edit opens profile setup with Cancel only when a saved profile exists. Cancel preserves the prior profile and returns to the active prompt. Once joined, the lobby shows ready/leave actions instead of profile edit controls.", "lobby.profileSummary, lobby.editProfile, conversation.profileSummary, conversation.editProfile, profile.cancel", "LobbyActions.swift; JoinGameView.swift; MessagesViewControllerRendering.swift; ProfileSetupView.swift", "ProfileStoreTests; FrontendInteractionContractTests", "Needs manual test", "Not run", "", "High", "Retain iMessage multi-participant manual pass; demo verifies saved-profile edit/cancel before joining and no profile edit path after joining"],
  ["HM-003", "Profile", "Local profile persistence", "As a player, my handle/avatar should be remembered locally between app launches.", "ProfileStore reads/writes the profile locally. Demo app supports -holdemResetProfile for clean UI-test runs.", "profile.save", "ProfileStore.swift; GameTableScreen.swift", "ProfileStoreTests; RiverInteractionTests", "Needs regression", "Not run", "", "Critical", "Kill/relaunch app and confirm saved identity appears before Join table"],
  ["HM-004", "Conversation", "No selected message start prompt", "As a configured player in Messages, I can start a new table from an empty conversation state.", "With no selected table message and a saved profile, renderer shows StartGameView with saved identity and Start table/Edit profile actions. Start sends a lobby message seeded with the local participant as first seat.", "conversation.startTable, conversation.editProfile", "MessagesViewControllerRendering.swift; TableMessageRenderer.swift; StartGameView.swift; TableMessageActions.swift", "MessageWireHelpers; PayloadSerializationTests", "Needs manual test", "Not run", "", "Critical", "Open extension without selected message, start table, inspect new bubble summary"],
  ["HM-005", "Lobby", "Join lobby with saved identity", "As an invited player, I join the lobby using my saved local profile.", "Join lobby operation uses saved name/avatar. Repeated joins are idempotent. Join is disabled when lobby is full.", "lobby.join", "LobbyView.swift; LobbyActions.swift; LobbyMutation.swift; LobbyMembershipOperation.swift", "LobbyTests; TableLobbyOperationTests", "Needs manual test", "Not run", "", "Critical", "Join as second simulator participant; verify saved handle/avatar and no editable seat name in lobby"],
  ["HM-006", "Lobby", "Ready/unready and auto-start", "As a seated player, I can ready or unready, and the game starts once at least two seated players are all ready.", "Ready button toggles ready state. Lobby.canStart requires at least two seats and all present players ready. Toggle-ready operation carries start seed and turn duration for deterministic hand start.", "lobby.ready", "Lobby.swift; LobbyReadyOperation.swift; LobbyStart.swift; TableMessageActions.swift; DemoLobby.swift", "LobbyTests; TableLobbyOperationTests; InitialHandSetupTests", "Needs manual test", "Not run", "", "Critical", "Use two players; verify unready prevents start and final ready transitions to table"],
  ["HM-007", "Lobby", "Leave lobby", "As a seated lobby player, I can leave before the game starts.", "Leave lobby removes only the local participant's seat and increments version when the seat existed. After leaving, the pre-join prompt returns with the saved local identity and edit action before rejoin.", "lobby.leave", "LobbyActions.swift; LobbyMutation.swift; LobbyMembershipOperation.swift; MessagesViewControllerActions.swift", "LobbyTests; TableLobbyOperationTests", "Needs manual test", "Not run", "", "High", "Retain iMessage multi-participant manual pass; demo verifies join, leave, saved-identity prompt, edit affordance, and rejoin"],
  ["HM-008", "Lobby", "Demo-only add player", "As a local demo tester, I can add stand-in players to start a pass-and-play game.", "DemoLobby exposes Add player only when the local demo user is joined and lobby is not full. Real iMessage renderer passes nil so the control is absent.", "lobby.addTestPlayer", "DemoLobby.swift; LobbyView.swift; LobbyActions.swift; TableMessageRenderer.swift", "RiverInteractionTests", "Needs manual test", "Not run", "", "Medium", "Ensure button absent in Messages flow but present in standalone demo"],
  ["HM-009", "Messages", "Compact game bubble opens expanded table", "As a seated player viewing a game bubble in compact presentation, I can open the full table.", "When seated and not game-over, compact presentation renders CompactSummaryView as a pressable 8pt rounded row with a clear open-table affordance. Open table requests expanded presentation. Expanded renders PokerTableView.", "conversation.openTable", "TableMessageRenderer.swift; CompactSummaryView.swift; MessagesViewControllerRendering.swift; PokerTableView.swift", "FrontendInteractionContractTests", "Needs manual test", "Not run", "", "Critical", "Tap compact bubble on Poker iPhone 16 and verify expanded table, not stale/join prompt"],
  ["HM-010", "Messages", "Invalid payload recovery", "As a user opening a corrupted table message, I should see a clear recovery state instead of a broken UI.", "Decode failures from selected message render StaleTableView with Invalid table message and invalid-payload context.", "conversation.recovery", "MessagePayloads.swift; TableMessageRenderer.swift; StaleTableView.swift; MessagesViewControllerRendering.swift", "LegacyPayloadTests; PayloadDurabilityTests", "Needs manual test", "Not run", "", "High", "Inject invalid URL payload in unit/UI harness and verify recovery copy"],
  ["HM-011", "Messages", "Stale/rejected action recovery", "As a player acting on an old bubble, I should be told the table moved on instead of sending bad state.", "RevisionStore marks older messages stale. Committer rejects stale/wrong phase/not actor/game-over operations. Renderer shows stale table recovery with reason context.", "conversation.recovery", "LatestRevisionStore.swift; TableRevisionTracker.swift; TableMessageCommitter.swift; MessagesViewControllerSending.swift; StaleTableView.swift", "TableRevisionTests; OperationHistoryTests; InvalidActionTests", "Needs manual test", "Not run", "", "Critical", "Use two bubbles out of order; tap old action and confirm no bad send"],
  ["HM-012", "Messages", "Send replacement message", "As a player taking any valid action, the app should send an encoded replacement message and dismiss only once Messages accepts the send.", "MessageSender creates MSMessage with caption 'River', subcaption summary, summaryText, and encoded URL. Sent means queued for async send; successful send remembers the revision and dismisses. Unchanged dismisses immediately. Send failure expands and shows stale/send-failed context without hiding recovery.", "iMessage bubble layout", "MessageSender.swift; MessagePayloads.swift; TableMessageCommitter.swift; MessagesViewControllerSending.swift", "PayloadSerializationTests; PayloadDurabilityTests", "Needs manual test", "Not run", "", "Critical", "Perform action, verify resulting iMessage bubble summary, success dismissal, and visible recovery on send failure"],
  ["HM-013", "In-progress join", "Join next hand from active game", "As a player not seated in an active game, I can join the table for the next hand using my saved profile.", "Unseated or has-left viewer gets JoinGameView with profile summary/edit and Join next hand. Operation adds player with configured starting stack for the next eligible hand.", "conversation.joinGame", "TableMessageRenderer.swift; JoinGameView.swift; GameMembershipOperation.swift; NextHandEligibilityTests", "JoinGameOperationTests; NextHandEligibilityTests", "Needs manual test", "Not run", "", "High", "Open active game from third participant and join; verify current hand integrity and next-hand inclusion"],
  ["HM-014", "Table", "Seat row and board state", "As a seated player, I can understand who is seated, whose turn it is, stacks, cards, board, and pot.", "PokerTableView composes seats row, BoardView, bottom controls, and hero dock from PokerTablePresentation. BoardView exposes table.board with a deterministic empty/card summary, pot exposes table.pot, and the hero dock shows the saved player name so the active identity is explicit.", "table.board, table.pot, table.heroSeat, seat labels", "PokerTableView.swift; PokerTableSeatsRow.swift; PlayerSeatView.swift; BoardView.swift; HeroHandDock.swift; HandStrengthBox.swift; PokerTablePresentation.swift", "FrontendInteractionContractTests; TableSummaryTests; RiverInteractionTests", "Needs manual test", "Not run", "", "Critical", "Play through preflop/flop/turn/river and check readability at compact iMessage size; keep verifying hero identity remains obvious after each actor/hand transition"],
  ["HM-015", "Table", "Current hand display", "As the acting player, I can see my identity, hole cards, and hand strength without exposing other players' private cards.", "HeroHandDock and HoleCardsView show the current hero's saved player name, hand, and hand strength; reveal/winning card presentation is handled by showdown presentation. Accessibility ID table.holeCards identifies the hero cards.", "table.heroSeat, table.holeCards", "HeroHandDock.swift; HandStrengthBox.swift; HoleCardsView.swift; PokerTableHeroPresentation.swift; PokerTableShowdownPresentation.swift", "FrontendInteractionContractTests; HandResultTests; RiverInteractionTests", "Needs manual test", "Not run", "", "Critical", "Confirm pass-and-play hero identity changes by actor and other hole cards stay hidden until showdown"],
  ["HM-016", "Table actions", "Fold/check/call legal action controls", "As the current actor, I only see legal primary actions and can submit them once.", "Presentation exposes legalActionsForHero only for current actor. ActionBarView renders fold/check/call based on LegalActions. Core revalidates and rejects illegal actions.", "table.action.fold, table.action.check, table.action.call", "PokerTableActionArea.swift; ActionBarView.swift; LegalActions.swift; PlayerActionMutation.swift; GameActionApplication.swift", "BettingResolutionTests; InvalidActionTests; FullHandMessagePassingTests", "Needs manual test", "Not run", "", "Critical", "Try each street and verify non-actor sees waiting bar, not buttons"],
  ["HM-017", "Table actions", "Raise slider and presets", "As the current actor, I can choose a valid raise with presets or slider and submit explicitly.", "Raise panel clamps selected total to legal min/max. Header shows the selected raise total with close affordance, the slider gets a full-width row, presets include +1 BB, 1/2 pot, pot, and the explicit Raise button submits .raise(to:) then closes.", "table.action.raise.expand, table.raise.slider, table.raise.submit, table.raise.preset.1bb, table.raise.preset.halfPot, table.raise.preset.pot, table.raise.close", "RaisePanelView.swift; ActionBarView.swift; RaisePreset.swift; LegalActions.swift; RaiseActionMutation.swift", "BettingRaiseTests; InvalidActionTests; FrontendInteractionContractTests", "Needs regression", "Not run", "", "Critical", "Retain exploratory chip/value pass; automated Poker iPhone 16 flow now adjusts the raise slider to min, max, and mid positions, taps +1 BB, pot, 1/2 pot, closes, reopens, and submits"],
  ["HM-018", "Table actions", "Waiting state", "As a non-actor or between actions, I see a concise waiting/status row instead of unusable controls.", "When no legal hero actions are available and hand is not resolved, PokerTableActionArea renders WaitingBar with presentation.waitingText and table.waiting identifier. Non-actors see the current player's saved name in the waiting copy when available; folded players still get a next-hand message.", "table.waiting", "PokerTableActionArea.swift; WaitingBar.swift; PokerTableActionPresentation.swift", "FrontendInteractionContractTests", "Needs manual test", "Not run", "", "High", "Observe other players' turns and timeout-resolved states; verify named actor waiting copy in multi-participant iMessage"],
  ["HM-019", "Table", "Turn clock and timeout", "As players take turns, the app should show a shared turn clock and resolve expired turns consistently.", "GameState stores turnStartedAt/turnDuration. TurnClock/GameTimeout resolve stale turns lazily when a client loads or acts. Active hero/opponent seat accessibility labels include the normalized turn-clock duration so the timer is not purely visual.", "turn clock visual; active seat accessibility labels", "TurnClock.swift; GameTimeout.swift; CountdownTimer.swift; DepletingBorder.swift; MessagesViewControllerRendering.swift; HandStrengthBox.swift; PlayerSeatView.swift", "TimeoutTests; TimeoutMessagePassingTests", "Needs manual test", "Not run", "", "High", "Wait past timeout on simulator, reopen/act, verify deterministic timeout action"],
  ["HM-020", "Table", "Leave active table confirmation", "As a seated player, I can leave the active table only after confirming.", "PokerTableView overlays LeaveTableButton when not game-over. The leave entry point is a visible 44pt icon control, exposes confirmation state for accessibility, reveals cancel/confirm actions, and confirm sends leaveGame. Core marks player left/forfeits hand as appropriate.", "table.leave, table.leave.cancel, table.leave.confirm", "PokerTableView.swift; LeaveTableButton.swift; GameLeaving.swift; PlayerLeavingLifecycleTests.swift", "LeaveGameOperationTests; PlayerLeavingLifecycleTests", "Needs regression", "Not run", "", "High", "Retain extended manual multi-player pass to verify excluded players stay out of later hands"],
  ["HM-021", "Hand lifecycle", "Street advancement", "As betting completes, the table advances from preflop through flop, turn, river, and showdown.", "StreetAdvancement advances only after betting round completion. Board cards are dealt by stage, pot/display summaries update. The standalone UI test now checks board counts at flop, turn, and river, then verifies the showdown/result state and Deal next hand action.", "table.board, table.result, table.action.dealNext", "StreetAdvancement.swift; GameAdvancement.swift; CardArrayDealing.swift; CommunityCardsView.swift; BoardStatusRow.swift; PokerTableActionArea.swift", "StreetAdvancementTests; PartialHandTests; FullHandMessagePassingTests; RiverInteractionTests", "Needs manual test", "Not run", "", "Critical", "Retain iMessage bubble-summary manual pass; standalone Poker iPhone 16 now verifies flop, turn, river, showdown result, and Deal next hand"],
  ["HM-022", "Hand lifecycle", "Uncontested hand result", "As players fold, the last active player should immediately win the hand.", "UncontestedAward and hand lifecycle assign pot, mark hand complete, and presentation shows a single accessible winner/result banner separate from any Deal next command.", "table.result, table.action.dealNext", "UncontestedAward.swift; HandLifecycle.swift; PokerTableActionArea.swift; ResultSummaryText.swift", "BettingResolutionTests; HandResultTests", "Needs manual test", "Not run", "", "Critical", "Fold all but one player and verify chip movement/result/deal-next"],
  ["HM-023", "Hand lifecycle", "Showdown and side pots", "As all-in or called hands reach showdown, winnings should be awarded accurately, including split/side pots.", "HandEvaluator, ShowdownRanking, SidePotAwarding, and HandSettlement compute ranked winners and payments. UI highlights winning cards and winner text, reveals contesting players' showdown cards, and the seat accessibility summary identifies revealed cards plus winning seats.", "table.result, seat labels", "HandEvaluator.swift; ShowdownRanking.swift; SidePotAwarding.swift; HandSettlement.swift; PokerTableShowdownPresentation.swift; PlayerSeatView.swift", "BestOfSevenTests; SidePotTests; SidePotMessagePassingTests; HandOrderingTests; FrontendInteractionContractTests", "Needs manual test", "Not run", "", "Critical", "Retain manual all-in/split-pot UX pass; package tests cover side-pot math and frontend contract now covers accessible revealed cards/winners"],
  ["HM-024", "Hand lifecycle", "Deal next hand", "As the table finishes a hand, an eligible player can deal the next hand and preserve stacks/seating.", "When hand complete and onDealNext exists, action area shows result status and a short Deal next hand command with a stable action identifier. Operation uses new seed, rotates dealer, excludes left/broke players, handles game over, and returns the UI to a fresh hand with an empty board.", "table.action.dealNext, table.board", "DealNextHandOperation.swift; NextHandLifecycle.swift; NextHandDealer.swift; PokerTableActionArea.swift; BoardView.swift", "DealNextHandOperationTests; NextHandDealerTests; NextHandStackTests; GameOverLifecycleTests; RiverInteractionTests", "Needs manual test", "Not run", "", "Critical", "Retain multi-hand manual pass for dealer/stacks; standalone Poker iPhone 16 verifies Deal next hand, fresh hole cards, cleared board, and hidden deal-next action"],
  ["HM-025", "Game over", "Game over presentation", "As the final winner or observer, I should see a clear game-over state and no table actions.", "If state.isGameOver, renderer shows GameOverView. The finished-game prompt exposes one deterministic accessible element labelled with Game over plus the final summary and announces that no actions are available. In the live table, the result banner distinguishes a final game win from a hand win with 'wins game'. Core rejects further game actions as gameOver.", "conversation.gameOver, table.result", "GameOverView.swift; TableMessageRenderer.swift; PokerTableActionArea.swift; GameActionApplication.swift; GameOverLifecycleTests.swift", "GameOverLifecycleTests; FrontendInteractionContractTests; RiverInteractionTests", "Needs manual test", "Not run", "", "High", "Play/eliminate to one winner or construct fixture; verify no leave/action controls and final live table says wins game"],
  ["HM-026", "Text/layout", "Stable compact text", "As a player using narrow iMessage UI, labels should fit without truncation that hides meaning or shifts layout.", "StableText is used on key buttons to constrain one-line text, scale where appropriate, and avoid clunky wrapping in action surfaces.", "visible button labels", "StableText.swift; ActionControls.swift; LobbyActionButtons.swift; ConversationActionButton.swift; LeaveTableButton.swift; WaitingBar.swift; ProfileSetupView.swift", "Not yet run after latest refactor", "Needs regression", "Not run", "Latest stable-text refactor has not been built/tested yet.", "Critical", "Run full build/test and manually inspect every button in iPhone 16 simulator"],
  ["HM-027", "Accessibility", "Automation identifiers", "As a tester, every important control should have stable identifiers for UI automation.", "HoldemAccessibility centralizes IDs for profile, lobby, conversation, table actions, raise panel, leave confirmation, and waiting/result states.", "all HoldemAccessibility IDs", "HoldemAccessibility.swift; OptionalAccessibilityIdentifier.swift; UI view files", "RiverInteractionTests; FrontendInteractionContractTests", "Needs regression", "Not run", "", "High", "Write/expand UI tests to hit every ID in this workbook"],
  ["HM-028", "Rules engine", "Payload durability and legacy handling", "As the game travels through Messages URLs, state should remain compact, decodable, and backward-compatible.", "Payload coders encode table messages/operations through URL-safe payloads. Legacy tests cover prior formats and malformed cases.", "MSMessage.url", "GamePayloadCoding.swift; GamePayloadURLCoding.swift; GameStateCoding.swift; LobbyCoding.swift; TableOperationPayload.swift; Base64URL.swift", "PayloadSerializationTests; PayloadDurabilityTests; LegacyPayloadTests", "Needs regression", "Not run", "", "Critical", "Run package tests after every payload-affecting UI/transport change"],
  ["HM-029", "Rules engine", "Duplicate/stale operation protection", "As multiple players act through async messages, duplicate or old operations should not corrupt state.", "Operation IDs are normalized/history-capped. Applied operation IDs and TableRevisionTracker reject duplicate/stale/wrong-base operations.", "operation history", "OperationIdentity.swift; TableOperationRecording.swift; TableRevisionTracker.swift; TableMessageOperationPayload.swift", "OperationHistoryTests; TableRevisionTests; FullHandMessagePassingTests", "Needs regression", "Not run", "", "Critical", "Replay same operation payload and older revision in tests/manual harness"],
  ["HM-030", "Native app", "Standalone pass-and-play demo", "As a developer/tester, I can run the standalone app and play a complete local game on one simulator.", "River starts GameTableScreen in dark mode. GameController uses local lobby state and pass-and-play current actor as hero.", "standalone app flow", "River.swift; GameTableScreen.swift; GameController.swift; DemoGameTable.swift", "RiverInteractionTests; GameControllerTests", "Needs manual test", "Not run", "", "High", "Reinstall on Poker iPhone 16, play many hands, document UX/logistics issues"]
];

const errorHeaders = ["Error ID", "Story ID", "Area", "Observed behavior", "Expected behavior", "Severity", "Source/Screen", "Fix status", "Retest status", "Notes"];
const testHeaders = ["Story ID", "Scenario", "Manual steps", "Expected result", "Evidence", "Result", "Error IDs", "Fix needed", "Retest result"];
const storyHeaders = ["Story ID", "Area", "Feature", "User story", "Expected behavior from code", "Entry points / IDs", "Source files", "Current coverage evidence", "Feature status", "Test status", "Errors / UX notes", "Priority", "Next action"];

const automatedPassEvidence = new Map([
  ["HM-001", "Passed: ProfileSetupView simplified into a compact one-title setup step with no instructional subtitle/helper copy; profile handle now visibly caps at ProfileText.maxNameLength during entry; build-ios-apps test_sim first-run profile setup, whitespace-only rejection, selected avatar accessibility, max-length entry, save gate, and persistence passed on Poker iPhone 16; Swift package suite 306/306."],
  ["HM-002", "Passed: build-ios-apps test_sim edit/cancel/save profile flow on Poker iPhone 16 after replacing the text edit affordance with a compact pencil icon target; same suite verifies profile summary/edit controls disappear after joining and ready actions replace them."],
  ["HM-003", "Passed: build-ios-apps test_sim profile save gate, max-length persistence, and relaunch persistence test on Poker iPhone 16."],
  ["HM-005", "Passed: build-ios-apps test_sim join table flow on Poker iPhone 16 after simplifying lobby primary buttons to one 8pt rounded shape; lobby operation tests passed in package suite."],
  ["HM-006", "Passed: build-ios-apps test_sim ready-to-start flow on Poker iPhone 16; lobby/start tests passed in package suite."],
  ["HM-007", "Passed: build-ios-apps test_sim lobby join, leave, saved-identity prompt return, edit affordance return, rejoin, and table observability flow on Poker iPhone 16."],
  ["HM-008", "Passed: build-ios-apps test_sim confirms demo Add player absent before profile and present after join."],
  ["HM-004", "Passed: package frontend contract tests for saved-profile start prompt, unified 8pt conversation action button, and TableMessageActions.newLobby."],
  ["HM-009", "Passed: package frontend contract tests for compact seated game rendering, pressable open-table row, and requestExpandedPresentation open action; full RiverInteractionTests suite passed on Poker iPhone 16."],
  ["HM-010", "Passed: package frontend contract tests for invalid selected payload recovery before profile/start fallback."],
  ["HM-011", "Passed: package frontend contract tests for stale/rejected action recovery with reason-specific copy."],
  ["HM-012", "Passed: package frontend contract tests for outgoing iMessage bubble caption, subcaption, summaryText, URL, send failure recovery, revision persistence, and dismissal only after send success; build-ios-apps UI test passed on Poker iPhone 16."],
  ["HM-013", "Passed: package frontend contract tests for saved-profile Join next hand prompt, unified 8pt conversation action button, and shared join-game operation tests."],
  ["HM-014", "Passed: build-ios-apps test_sim table observability checks for board, pot, and named hero seat on Poker iPhone 16; frontend contract tests cover table.board label and hero-seat name plumbing."],
  ["HM-015", "Passed: build-ios-apps test_sim hole-card and named hero-seat accessibility/readability checks after fixing duplicate table.holeCards elements and anonymous hero dock identity."],
  ["HM-016", "Passed: build-ios-apps test_sim fold action flow after unifying fold/check/call/raise controls to 8pt rounded action buttons; betting/invalid-action tests passed in package suite."],
  ["HM-017", "Passed: raise panel simplified into header/full-width slider/preset-submit rows and presets now share the 8pt action-control shape; Swift package suite 306/306 and build-ios-apps test_sim adjusts the slider to min, max, and mid positions, verifies accessible selected values, taps +1 BB, pot, 1/2 pot, close, reopen, and submit through the full RiverInteractionTests suite on Poker iPhone 16."],
  ["HM-018", "Passed: package frontend contract tests for non-actor waiting mode, named current-player waiting copy, folded-player waiting copy, table.waiting identifier, and 8pt waiting bar shape."],
  ["HM-019", "Passed: package timeout tests plus frontend contract tests proving render-time timeout resolution, normalized visual clocks, and active seat accessibility labels that include the shared turn-clock duration; full RiverInteractionTests passed on Poker iPhone 16."],
  ["HM-020", "Passed: visible 44pt leave control with confirmation-state accessibility and unified 8pt framed stay/leave confirmation controls; Swift package suite 306/306 and build-ios-apps leave cancel plus destructive confirm heads-up game-over paths passed on Poker iPhone 16."],
  ["HM-021", "Passed: package street advancement/full hand tests plus build-ios-apps check/call board-progression UI path on Poker iPhone 16 covering flop, turn, river, showdown result, and Deal next hand."],
  ["HM-022", "Passed: build-ios-apps test_sim fold-to-result/deal-next flow after splitting winner status from Deal next command and fixing duplicate table.result accessibility; hand result tests passed."],
  ["HM-023", "Passed: package showdown/side-pot/best-of-seven tests plus frontend contract for accessible revealed showdown cards and winning seats; still needs manual all-in UX pass."],
  ["HM-024", "Passed: build-ios-apps test_sim deal-next flow with short Deal next hand label, fresh hole cards, cleared board, and hidden deal-next action on Poker iPhone 16; next-hand package tests passed."],
  ["HM-025", "Passed: package frontend contract tests for game-over renderer ordering, deterministic Game over accessibility label/value, and live table final-result copy that says wins game; game-over lifecycle tests passed; full RiverInteractionTests passed on Poker iPhone 16."],
  ["HM-026", "Passed: package frontend contract tests after stable-text helper test update, compact open-table affordance polish, tighter first-run profile layout, unified 8pt lobby/conversation/table/leave controls, centralized control radius, and centralized table action/compact control heights in Theme.Metrics; full RiverInteractionTests suite passed on Poker iPhone 16."],
  ["HM-027", "Passed: build-ios-apps test_sim used key accessibility IDs; frontend contract tests passed, including selected avatar trait, profile preview label, table.board, table.leave accessibility value, conversation.gameOver label/value, and active seat clock labels."],
  ["HM-028", "Passed: package payload serialization/durability/legacy tests."],
  ["HM-029", "Passed: package operation history/revision tests."],
  ["HM-030", "Passed: build-ios-apps test_sim standalone pass-and-play smoke path on Poker iPhone 16, including saved-profile identity appearing in the acting hero seat and leave-confirmation game-over copy saying wins game."]
]);

for (const row of stories) {
  const evidence = automatedPassEvidence.get(row[0]);
  if (!evidence) continue;
  row[8] = row[8] === "Needs regression" ? "Needs regression" : "In progress";
  row[9] = "Pass";
  row[10] = evidence;
  if (!row[12].startsWith("Retain ")) {
    row[12] = `${row[12]} Retain manual exploratory pass for UX polish.`;
  }
}

const testScenarios = stories.map((row) => [
  row[0],
  row[2],
  row[12],
  row[4],
  automatedPassEvidence.get(row[0]) ?? "",
  automatedPassEvidence.has(row[0]) ? "Pass" : "Not run",
  "",
  "",
  automatedPassEvidence.has(row[0]) ? "Pass" : "Not run"
]);

const workbook = Workbook.create();
const summary = workbook.worksheets.add("Summary");
const features = workbook.worksheets.add("Feature Stories");
const tests = workbook.worksheets.add("Test Loop");
const errors = workbook.worksheets.add("Errors");

for (const sheet of [summary, features, tests, errors]) {
  sheet.showGridLines = false;
}

features.getRange("A1:M1").values = [storyHeaders];
features.getRangeByIndexes(1, 0, stories.length, storyHeaders.length).values = stories;
tests.getRange("A1:I1").values = [testHeaders];
tests.getRangeByIndexes(1, 0, testScenarios.length, testHeaders.length).values = testScenarios;
errors.getRange("A1:J1").values = [errorHeaders];
errors.getRange("A2:J2").values = [["", "", "", "", "", "", "", "", "", ""]];

const titleStyle = {
  fill: "#111827",
  font: { bold: true, color: "#FFFFFF" },
};
for (const [sheet, range] of [[features, "A1:M1"], [tests, "A1:I1"], [errors, "A1:J1"]]) {
  sheet.getRange(range).format = titleStyle;
  sheet.getRange(range).format.rowHeightPx = 34;
  sheet.freezePanes.freezeRows(1);
}

features.getRange(`A1:M${stories.length + 1}`).format.wrapText = true;
tests.getRange(`A1:I${testScenarios.length + 1}`).format.wrapText = true;
errors.getRange("A1:J2").format.wrapText = true;

features.getRange("A:A").format.columnWidthPx = 82;
features.getRange("B:B").format.columnWidthPx = 104;
features.getRange("C:C").format.columnWidthPx = 185;
features.getRange("D:D").format.columnWidthPx = 300;
features.getRange("E:E").format.columnWidthPx = 390;
features.getRange("F:F").format.columnWidthPx = 230;
features.getRange("G:G").format.columnWidthPx = 310;
features.getRange("H:H").format.columnWidthPx = 230;
features.getRange("I:J").format.columnWidthPx = 128;
features.getRange("K:K").format.columnWidthPx = 250;
features.getRange("L:L").format.columnWidthPx = 96;
features.getRange("M:M").format.columnWidthPx = 310;
features.getRangeByIndexes(1, 0, stories.length, storyHeaders.length).format.rowHeightPx = 112;

tests.getRange("A:A").format.columnWidthPx = 82;
tests.getRange("B:B").format.columnWidthPx = 190;
tests.getRange("C:C").format.columnWidthPx = 330;
tests.getRange("D:D").format.columnWidthPx = 390;
tests.getRange("E:E").format.columnWidthPx = 180;
tests.getRange("F:I").format.columnWidthPx = 130;
tests.getRangeByIndexes(1, 0, testScenarios.length, testHeaders.length).format.rowHeightPx = 118;

errors.getRange("A:A").format.columnWidthPx = 90;
errors.getRange("B:C").format.columnWidthPx = 100;
errors.getRange("D:E").format.columnWidthPx = 340;
errors.getRange("F:I").format.columnWidthPx = 120;
errors.getRange("J:J").format.columnWidthPx = 250;

features.tables.add(`A1:M${stories.length + 1}`, true, "FeatureStories");
tests.tables.add(`A1:I${testScenarios.length + 1}`, true, "TestLoop");
errors.tables.add("A1:J2", true, "Errors");

features.getRange(`I2:I${stories.length + 1}`).dataValidation = { rule: { type: "list", values: ["Needs manual test", "Needs regression", "In progress", "Blocked", "Fixed", "Low value"] } };
features.getRange(`J2:J${stories.length + 1}`).dataValidation = { rule: { type: "list", values: ["Not run", "Pass", "Fail", "Blocked"] } };
features.getRange(`L2:L${stories.length + 1}`).dataValidation = { rule: { type: "list", values: ["Critical", "High", "Medium", "Low"] } };
tests.getRange(`F2:F${testScenarios.length + 1}`).dataValidation = { rule: { type: "list", values: ["Not run", "Pass", "Fail", "Blocked"] } };
tests.getRange(`I2:I${testScenarios.length + 1}`).dataValidation = { rule: { type: "list", values: ["Not run", "Pass", "Fail", "Blocked"] } };
errors.getRange("F2:F200").dataValidation = { rule: { type: "list", values: ["Critical", "High", "Medium", "Low"] } };
errors.getRange("H2:I200").dataValidation = { rule: { type: "list", values: ["Open", "Fixed", "Won't fix", "Blocked", "Retest pass", "Retest fail"] } };

for (const range of [features.getRange(`A1:M${stories.length + 1}`), tests.getRange(`A1:I${testScenarios.length + 1}`), errors.getRange("A1:J2")]) {
  range.format.borders = { preset: "outside", style: "thin", color: "#CBD5E1" };
}

summary.getRange("A1:H1").merge();
summary.getRange("A1").values = [["Texas River iMessage Canonical User Story Tracker"]];
summary.getRange("A1").format = { fill: "#111827", font: { bold: true, color: "#FFFFFF", size: 18 } };
summary.getRange("A1").format.rowHeightPx = 42;
summary.getRange("A3:B10").values = [
  ["Generated", new Date()],
  ["Scope", "Every frontend-relevant feature currently visible in code"],
  ["Slash goal operating loop", "Create code-backed user stories, test every story, document every error, fix UX/logistics errors, then retest every behavior post-fix"],
  ["Total stories", stories.length],
  ["Critical stories", null],
  ["Stories not run", null],
  ["Open errors", null],
  ["Stop condition", "Continue until remaining improvements are objectively low-value or blocked by product/platform decisions"]
];
summary.getRange("A3:B10").format.wrapText = true;
summary.getRange("B3").setNumberFormat("yyyy-mm-dd hh:mm");
summary.getRange("B7").formulas = [[`=COUNTIF('Feature Stories'!L2:L${stories.length + 1},"Critical")`]];
summary.getRange("B8").formulas = [[`=COUNTIF('Feature Stories'!J2:J${stories.length + 1},"Not run")`]];
summary.getRange("B9").formulas = [[`=COUNTIF(Errors!H2:H200,"Open")`]];
summary.getRange("A3:A10").format = { fill: "#E5E7EB", font: { bold: true, color: "#111827" } };
summary.getRange("B3:B10").format = { fill: "#F8FAFC", font: { color: "#111827" } };
summary.getRange("A3:B10").format.borders = { preset: "outside", style: "thin", color: "#CBD5E1" };
summary.getRange("A12:E12").values = [["Phase", "Definition of done", "Status", "Evidence", "Next action"]];
summary.getRange("A13:E16").values = [
  ["1. Inventory", "Every code-backed feature has a user story and expected behavior", "Complete in this workbook", "Feature Stories sheet", "Keep tracker updated as code changes"],
  ["2. Test loop", "Every story receives manual or automated result plus evidence", "In progress", "Test Loop sheet", "Continue manual iPhone 16 gameplay across remaining untested stories"],
  ["3. Fix loop", "Every UX/logistics error has source fix and status", "Not started", "Errors sheet", "Patch app in priority order"],
  ["4. Retest loop", "Every fixed story is retested and marked pass/fail", "Not started", "Feature Stories/Test Loop", "Repeat until only low-value or blocked work remains"]
];
summary.getRange("A12:E12").format = titleStyle;
summary.getRange("A12:E16").format.wrapText = true;
summary.getRange("A:A").format.columnWidthPx = 130;
summary.getRange("B:B").format.columnWidthPx = 370;
summary.getRange("C:C").format.columnWidthPx = 160;
summary.getRange("D:D").format.columnWidthPx = 220;
summary.getRange("E:E").format.columnWidthPx = 320;
summary.getRange("A13:E16").format.rowHeightPx = 86;
summary.freezePanes.freezeRows(1);

for (const [sheetName, range] of [
  ["Feature Stories", `I2:J${stories.length + 1}`],
  ["Test Loop", `F2:F${testScenarios.length + 1}`],
  ["Errors", "H2:I200"]
]) {
  const sheet = workbook.worksheets.getItem(sheetName);
  const target = sheet.getRange(range);
  target.conditionalFormats.add("containsText", { text: "Fail", format: { fill: "#FEE2E2", font: { color: "#991B1B", bold: true } } });
  target.conditionalFormats.add("containsText", { text: "Pass", format: { fill: "#DCFCE7", font: { color: "#166534", bold: true } } });
  target.conditionalFormats.add("containsText", { text: "Not run", format: { fill: "#FEF3C7", font: { color: "#92400E" } } });
  target.conditionalFormats.add("containsText", { text: "Blocked", format: { fill: "#E5E7EB", font: { color: "#374151", bold: true } } });
}

const previewSummary = await workbook.render({ sheetName: "Summary", autoCrop: "all", scale: 1, format: "png" });
await fs.writeFile(`${outputDir}/summary_preview.png`, new Uint8Array(await previewSummary.arrayBuffer()));
const previewFeatures = await workbook.render({ sheetName: "Feature Stories", autoCrop: "all", scale: 0.65, format: "png" });
await fs.writeFile(`${outputDir}/feature_stories_preview.png`, new Uint8Array(await previewFeatures.arrayBuffer()));

const exported = await SpreadsheetFile.exportXlsx(workbook);
await exported.save(xlsxPath);

console.log(xlsxPath);
