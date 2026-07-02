import Foundation
import Testing

@Suite("Frontend interaction contracts")
struct FrontendInteractionContractTests {
    @Test("table action row exposes fold as a visible button")
    func tableActionRowExposesFoldAsVisibleButton() throws {
        let source = try sourceFile("Sources/HoldemUI/ActionBarView.swift")

        #expect(source.contains("onFold"))
        #expect(source.contains("HoldemAccessibility.Table.fold"))
        #expect(source.contains("ActionDestructiveButton"))
    }

    @Test("hole-card fold shortcut resets its drag state before sending")
    func holeCardFoldShortcutResetsDragStateBeforeSending() throws {
        let source = try sourceFile("Sources/HoldemUI/HoleCardsView.swift")
        let resetRange = source.range(of: "withAnimation(.tableSnap) { dragY = 0 }")
        let foldRange = source.range(of: "onFold?()")

        #expect(source.contains("value.translation.height < -80"))
        #expect(source.contains(".accessibilityElement(children: .ignore)"))
        #expect(source.contains("HoldemAccessibility.Table.holeCards"))
        #expect(resetRange != nil)
        #expect(foldRange != nil)
        if let resetRange, let foldRange {
            #expect(resetRange.lowerBound < foldRange.lowerBound)
        }
    }

    @Test("primary raise action opens sizing instead of firing a blind min raise")
    func primaryRaiseActionOpensSizingInsteadOfFiringBlindMinRaise() throws {
        let source = try sourceFile("Sources/HoldemUI/ActionBarView.swift")

        #expect(source.contains("title: \"Raise\""))
        #expect(source.contains("accessibilityID: HoldemAccessibility.Table.expandRaise"))
        #expect(!source.contains("title: \"Raise \\("))
        #expect(!source.contains("accessibilityID: HoldemAccessibility.Table.minRaise"))
    }

    @Test("table action labels stay inside fixed controls")
    func tableActionLabelsStayInsideFixedControls() throws {
        let controls = try sourceFile("Sources/HoldemUI/ActionControls.swift")
        let actionArea = try sourceFile("Sources/HoldemUI/PokerTableActionArea.swift")
        let stableText = try sourceFile("Sources/HoldemUI/StableText.swift")
        let waiting = try sourceFile("Sources/HoldemUI/WaitingBar.swift")
        let raisePanel = try sourceFile("Sources/HoldemUI/RaisePanelView.swift")
        let theme = try sourceFile("Sources/HoldemUI/Theme.swift")

        #expect(theme.contains("static let actionControlHeight: CGFloat = 56"))
        #expect(theme.contains("static let compactControlHeight: CGFloat = 44"))
        #expect(stableText.contains("lineLimit(1)"))
        #expect(stableText.contains(".minimumScaleFactor(minScale)"))
        #expect(stableText.contains(".allowsTightening(true)"))
        #expect(controls.contains(".stableOneLineText(minScale: 0.78)"))
        #expect(controls.contains(".frame(height: Theme.Metrics.actionControlHeight)"))
        #expect(controls.contains("var width: CGFloat = Theme.Metrics.actionControlHeight"))
        #expect(controls.contains("var height: CGFloat = Theme.Metrics.actionControlHeight"))
        #expect(controls.contains(".frame(height: Theme.Metrics.compactControlHeight)"))
        #expect(controls.contains("RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner).fill(Theme.controlBackground)"))
        #expect(controls.contains("RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)\n                        .fill(Theme.dangerBackground)"))
        #expect(controls.contains("var cornerRadius: CGFloat = Theme.Metrics.controlCorner"))
        #expect(!controls.contains("cornerRadius: 14"))
        #expect(!controls.contains(".frame(height: 56)"))
        #expect(!controls.contains(".frame(height: 44)"))
        #expect(actionArea.contains("Text(\"Deal next hand\")"))
        #expect(actionArea.contains(".stableOneLineText(minScale: 0.82)"))
        #expect(actionArea.contains(".frame(height: Theme.Metrics.actionControlHeight)"))
        #expect(actionArea.contains("Label(text, systemImage: \"trophy.fill\")"))
        #expect(actionArea.contains(".accessibilityElement(children: .ignore)"))
        #expect(actionArea.contains(".accessibilityLabel(text)"))
        #expect(actionArea.contains(".lineLimit(1)"))
        #expect(actionArea.contains(".minimumScaleFactor(0.78)"))
        #expect(actionArea.contains(".allowsTightening(true)"))
        #expect(waiting.contains(".stableOneLineText(minScale: 0.78)"))
        #expect(waiting.contains(".frame(height: Theme.Metrics.actionControlHeight)"))
        #expect(waiting.contains("RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)"))
        #expect(!waiting.contains("cornerRadius: 14"))
        #expect(raisePanel.contains(".frame(height: Theme.Metrics.compactControlHeight)"))
    }

    @Test("raise panel announces the selected raise target")
    func raisePanelAnnouncesTheSelectedRaiseTarget() throws {
        let source = try sourceFile("Sources/HoldemUI/RaisePanelView.swift")

        #expect(source.contains(".accessibilityLabel(\"Raise amount\")"))
        #expect(source.contains(".accessibilityValue(selectedRaiseText)"))
        #expect(source.contains(".accessibilityLabel(\"Raise to \\(selectedRaiseText)\")"))
        #expect(source.contains("onRaise(selectedRaiseTo)"))
        #expect(source.contains("private var selectedRaiseTo: Int"))
        #expect(source.contains("ChipFormatter.string(selectedRaiseTo)"))
        #expect(source.contains("Label(\"Raise to \\(selectedRaiseText)\", systemImage: \"arrow.up\")"))
        #expect(source.contains("ActionIconButton(systemName: \"xmark\""))
        #expect(source.contains("Text(\"Raise\")"))
        #expect(source.contains(".frame(minWidth: 70)"))
        #expect(source.contains("RaisePresetButton(title: \"+1 BB\""))
        #expect(!source.contains("RaisePresetButton(title: \"1 BB\""))
        #expect(source.contains("withAnimation(.tableSnap)"))
        #expect(!source.contains(".accessibilityLabel(\"Submit raise\")"))
    }

    @Test("table action presentation does not render an empty action row")
    func tableActionPresentationDoesNotRenderEmptyActionRow() throws {
        let presentation = try sourceFile("Sources/HoldemUI/PokerTableActionPresentation.swift")
        let actionArea = try sourceFile("Sources/HoldemUI/PokerTableActionArea.swift")
        let legal = try sourceFile("Sources/GameCore/LegalActions.swift")
        let waiting = try sourceFile("Sources/HoldemUI/WaitingBar.swift")
        let accessibility = try sourceFile("Sources/HoldemUI/HoldemAccessibility.swift")

        #expect(legal.contains("public var hasAvailableAction: Bool"))
        #expect(presentation.contains("let legal = state.legalActions(for: heroIndex)"))
        #expect(presentation.contains("return legal.hasAvailableAction ? legal : nil"))
        #expect(actionArea.contains("} else if let legal = presentation.legalActionsForHero() {"))
        #expect(actionArea.contains("WaitingBar(text: presentation.waitingText)"))
        #expect(accessibility.contains("static let waiting = \"table.waiting\""))
        #expect(waiting.contains("HoldemAccessibility.Table.waiting"))
    }

    @Test("profile setup exposes a labelled handle field and explicit save action")
    func profileSetupExposesLabelledHandleFieldAndExplicitSaveAction() throws {
        let source = try sourceFile("Sources/HoldemUI/ProfileSetupView.swift")

        #expect(source.contains("import GameCore"))
        #expect(source.contains("ScrollView"))
        #expect(source.contains(".scrollDismissesKeyboard(.interactively)"))
        #expect(source.contains(".safeAreaInset(edge: .bottom)"))
        #expect(source.contains("private var actions: some View"))
        #expect(source.contains("Text(\"Handle\")"))
        #expect(!source.contains("Choose how you show up"))
        #expect(!source.contains("Shown to everyone in the chat."))
        #expect(source.contains(".padding(.horizontal, 20)"))
        #expect(source.contains("RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)"))
        #expect(source.contains("@FocusState private var isHandleFocused"))
        #expect(source.contains(".textContentType(.nickname)"))
        #expect(source.contains(".autocorrectionDisabled()"))
        #expect(source.contains(".submitLabel(.done)"))
        #expect(source.contains(".focused($isHandleFocused)"))
        #expect(source.contains(".onSubmit {\n                    if hasName { saveProfile() }\n                }"))
        #expect(source.contains("CharacterPicker("))
        #expect(source.contains(".accessibilityLabel(\"Selected character \\(avatar)\")"))
        #expect(source.contains("accessibilityIdentifier(HoldemAccessibility.Profile.nameField)"))
        #expect(source.contains("accessibilityIdentifier(HoldemAccessibility.Profile.save)"))
        #expect(source.contains("accessibilityIdentifier(HoldemAccessibility.Profile.cancel)"))
        #expect(source.contains("isHandleFocused = false"))
        #expect(source.contains(".stableOneLineText()"))
        #expect(source.contains("private func saveProfile()"))
    }

    @Test("profile setup edits the same bounded identity saved to multiplayer")
    func profileSetupEditsSameBoundedIdentitySavedToMultiplayer() throws {
        let source = try sourceFile("Sources/HoldemUI/ProfileSetupView.swift")
        let profileText = try sourceFile("Sources/GameCore/ProfileText.swift")

        #expect(source.contains("avatar: String = \"🙂\""))
        #expect(source.contains("private var handle: Binding<String>"))
        #expect(source.contains("String($0.prefix(ProfileText.maxNameLength))"))
        #expect(source.contains("TextField(\"\", text: handle"))
        #expect(source.contains("onSave(ProfileText.name(name), ProfileText.avatar(avatar))"))
        #expect(profileText.contains("public static let maxAvatarLength"))
        #expect(profileText.contains("String(trimmed.prefix(maxAvatarLength))"))
    }

    @Test("profile setup cancel is only available for existing profiles")
    func profileSetupCancelIsOnlyAvailableForExistingProfiles() throws {
        let setup = try sourceFile("Sources/HoldemUI/ProfileSetupView.swift")
        let accessibility = try sourceFile("Sources/HoldemUI/HoldemAccessibility.swift")
        let screen = try sourceFile("Sources/HoldemUI/GameTableScreen.swift")
        let renderer = try repoFile("MessagesExtension/TableMessageRenderer.swift")
        let rendering = try repoFile("MessagesExtension/MessagesViewControllerRendering.swift")

        #expect(setup.contains("onCancel: (() -> Void)? = nil"))
        #expect(setup.contains("if let onCancel"))
        #expect(accessibility.contains("static let cancel = \"profile.cancel\""))
        #expect(screen.contains("onCancel: profileSetupCancelAction"))
        #expect(screen.contains("private var profileSetupCancelAction: (() -> Void)?"))
        #expect(screen.contains("guard profile.hasProfile else { return nil }"))
        #expect(screen.contains("return { cancelProfileEdit() }"))
        #expect(screen.contains("private func cancelProfileEdit()"))
        #expect(renderer.contains("onCancel: (() -> Void)? = nil"))
        #expect(renderer.contains("onCancel: onCancel"))
        #expect(rendering.contains("let canCancel = isEditingExistingProfile && profile.hasProfile"))
        #expect(rendering.contains("self?.isEditingProfile = false"))
        #expect(rendering.contains("onCancel: canCancel ? { [weak self] in"))
    }

    @Test("character setup copy does not leak into the lobby")
    func characterSetupCopyDoesNotLeakIntoTheLobby() throws {
        let characterPicker = try sourceFile("Sources/HoldemUI/CharacterPicker.swift")
        let lobbyModel = try sourceFile("Sources/GameCore/Lobby.swift")
        let lobby = try sourceFile("Sources/HoldemUI/LobbyView.swift")
        let seatList = try sourceFile("Sources/HoldemUI/LobbySeatList.swift")

        #expect(!characterPicker.contains("Your character"))
        #expect(lobbyModel.contains("Identity is configured before"))
        #expect(lobbyModel.contains("the lobby only tracks seats and readiness"))
        #expect(!lobbyModel.contains("picks a"))
        #expect(!lobbyModel.contains("pick a character"))
        #expect(!lobby.contains("CharacterPicker("))
        #expect(!seatList.contains("\" (you)\""))
    }

    @Test("lobby seats show explicit readiness states")
    func lobbySeatsShowExplicitReadinessStates() throws {
        let seatList = try sourceFile("Sources/HoldemUI/LobbySeatList.swift")

        #expect(seatList.contains("Label(\"Ready\""))
        #expect(seatList.contains("Label(\"Not ready\""))
        #expect(seatList.contains(".accessibilityElement(children: .ignore)"))
        #expect(seatList.contains(".accessibilityLabel(accessibilityLabel)"))
        #expect(seatList.contains("let owner = isLocal ? \"You, \" : \"\""))
        #expect(seatList.contains("let readiness = seat.isReady ? \"Ready\" : \"Not ready\""))
        #expect(seatList.contains(".lineLimit(1)"))
        #expect(seatList.contains(".minimumScaleFactor(0.82)"))
        #expect(seatList.contains(".allowsTightening(true)"))
        #expect(!seatList.contains("Text(\"…\")"))
    }

    @Test("character picker belongs to profile setup, not lobby")
    func characterPickerBelongsToProfileSetupNotLobby() throws {
        let accessibility = try sourceFile("Sources/HoldemUI/HoldemAccessibility.swift")
        let characterPicker = try sourceFile("Sources/HoldemUI/CharacterPicker.swift")

        #expect(accessibility.contains("enum Profile"))
        #expect(accessibility.contains("static func avatar(_ index: Int) -> String"))
        #expect(accessibility.contains("\"profile.avatar.\\(index)\""))
        #expect(characterPicker.contains("HoldemAccessibility.Profile.avatar(index)"))
        #expect(characterPicker.contains(".accessibilityLabel(isSelected ? \"Selected character \\(emoji)\" : \"Choose character \\(emoji)\")"))
        #expect(characterPicker.contains(".accessibilityAddTraits(isSelected ? .isSelected : [])"))
        #expect(!characterPicker.contains("HoldemAccessibility.Lobby.avatar(index)"))
        #expect(!accessibility.contains("\"lobby.avatar.\\(index)\""))
    }

    @Test("lobby keeps seats scrollable and actions pinned")
    func lobbyKeepsSeatsScrollableAndActionsPinned() throws {
        let source = try sourceFile("Sources/HoldemUI/LobbyView.swift")

        #expect(source.contains("ScrollView"))
        #expect(source.contains("safeAreaInset(edge: .bottom)"))
        #expect(!source.contains("CharacterPicker("))
        #expect(!source.contains("Spacer(minLength: 8)"))
    }

    @Test("pinned lobby actions contain only commands, not the avatar grid")
    func pinnedLobbyActionsContainOnlyCommandsNotAvatarGrid() throws {
        let source = try sourceFile("Sources/HoldemUI/LobbyActions.swift")

        #expect(source.contains("VStack(spacing: 12)"))
        #expect(!source.contains("CharacterPicker("))
    }

    @Test("demo lobby actions do not expose developer copy")
    func demoLobbyActionsDoNotExposeDeveloperCopy() throws {
        let source = try sourceFile("Sources/HoldemUI/LobbyActions.swift")

        #expect(source.contains("Label(\"Add player\""))
        #expect(!source.contains("Add test player"))
    }

    @Test("conversation entry states expose stable action identifiers")
    func conversationEntryStatesExposeStableActionIdentifiers() throws {
        let prompt = try sourceFile("Sources/HoldemUI/ConversationPrompt.swift")
        let start = try sourceFile("Sources/HoldemUI/StartGameView.swift")
        let join = try sourceFile("Sources/HoldemUI/JoinGameView.swift")
        let gameOver = try sourceFile("Sources/HoldemUI/GameOverView.swift")
        let tableActionArea = try sourceFile("Sources/HoldemUI/PokerTableActionArea.swift")
        let compact = try sourceFile("Sources/HoldemUI/CompactSummaryView.swift")
        let stale = try sourceFile("Sources/HoldemUI/StaleTableView.swift")
        let accessibility = try sourceFile("Sources/HoldemUI/HoldemAccessibility.swift")

        #expect(prompt.contains("ScrollView"))
        #expect(prompt.contains(".fixedSize(horizontal: false, vertical: true)"))
        #expect(prompt.contains(".lineLimit(1)"))
        #expect(prompt.contains(".minimumScaleFactor(0.78)"))
        #expect(!prompt.contains(".padding(40)"))
        #expect(start.contains("HoldemAccessibility.Conversation.startTable"))
        #expect(start.contains("ConversationPrompt(icon: .system(\"suit.spade.fill\")"))
        #expect(start.contains("summaryAccessibilityID: HoldemAccessibility.Conversation.profileSummary"))
        #expect(start.contains("editAccessibilityID: HoldemAccessibility.Conversation.editProfile"))
        #expect(!start.contains("usesPressFeedback: false"))
        #expect(join.contains("HoldemAccessibility.Conversation.joinGame"))
        #expect(join.contains("ConversationPrompt(icon: .system(\"suit.spade.fill\")"))
        #expect(join.contains("summaryAccessibilityID: HoldemAccessibility.Conversation.profileSummary"))
        #expect(join.contains("editAccessibilityID: HoldemAccessibility.Conversation.editProfile"))
        #expect(gameOver.contains("HoldemAccessibility.Conversation.gameOver"))
        #expect(gameOver.contains("ConversationPrompt(icon: .system(\"trophy.fill\")"))
        #expect(gameOver.contains(".accessibilityElement(children: .ignore)"))
        #expect(gameOver.contains(".accessibilityLabel(\"Game over. \\(summary)\")"))
        #expect(gameOver.contains(".accessibilityValue(\"No actions available\")"))
        #expect(tableActionArea.contains("ResultBanner(text: \"\\(winner.name) wins game\")"))
        #expect(compact.contains("HoldemAccessibility.Conversation.openTable"))
        #expect(compact.contains("Image(systemName: \"suit.spade.fill\")"))
        #expect(compact.contains("Image(systemName: \"arrow.up.forward.app\")"))
        #expect(compact.contains(".fixedSize(horizontal: true, vertical: false)"))
        #expect(compact.contains("Spacer(minLength: 12)"))
        #expect(compact.contains(".minimumScaleFactor(0.82)"))
        #expect(compact.contains(".buttonStyle(PressableButtonStyle())"))
        #expect(compact.contains("RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)"))
        #expect(compact.contains(".contentShape(RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner))"))
        #expect(compact.contains(".frame(maxWidth: .infinity, minHeight: 64)"))
        #expect(compact.contains(".frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)"))
        #expect(compact.contains(".frame(width: 18, alignment: .trailing)"))
        #expect(compact.contains(".accessibilityLabel(\"Open table. \\(summary)\")"))
        #expect(!compact.contains("Image(systemName: \"chevron.up\")"))
        #expect(accessibility.contains("static let recovery = \"conversation.recovery\""))
        #expect(stale.contains("HoldemAccessibility.Conversation.recovery"))
        #expect(stale.contains(".fixedSize(horizontal: false, vertical: true)"))
    }

    @Test("conversation start screen shows saved profile before creating a table")
    func conversationStartScreenShowsSavedProfileBeforeCreatingTable() throws {
        let start = try sourceFile("Sources/HoldemUI/StartGameView.swift")
        let renderer = try repoFile("MessagesExtension/TableMessageRenderer.swift")
        let rendering = try repoFile("MessagesExtension/MessagesViewControllerRendering.swift")

        #expect(start.contains("profileName: String"))
        #expect(start.contains("profileAvatar: String"))
        #expect(start.contains("onEditProfile: @escaping () -> Void"))
        #expect(start.contains("ProfileSummaryRow("))
        #expect(start.contains("onEditProfile: onEditProfile"))
        #expect(start.contains("HoldemAccessibility.Conversation.profileSummary"))
        #expect(start.contains("HoldemAccessibility.Conversation.editProfile"))
        #expect(renderer.contains("func showStart(name: String, avatar: String,"))
        #expect(renderer.contains("StartGameView(profileName: name, profileAvatar: avatar"))
        #expect(rendering.contains("tableRenderer.showStart("))
        #expect(rendering.contains("name: profile.name"))
        #expect(rendering.contains("avatar: profile.avatar"))
        #expect(rendering.contains("onEditProfile: { [weak self] in self?.renderProfileSetup(isEditingExistingProfile: true) }"))
    }

    @Test("conversation join screen shows saved profile before joining a hand")
    func conversationJoinScreenShowsSavedProfileBeforeJoiningHand() throws {
        let join = try sourceFile("Sources/HoldemUI/JoinGameView.swift")
        let renderer = try repoFile("MessagesExtension/TableMessageRenderer.swift")
        let rendering = try repoFile("MessagesExtension/MessagesViewControllerRendering.swift")

        #expect(join.contains("profileName: String"))
        #expect(join.contains("profileAvatar: String"))
        #expect(join.contains("onEditProfile: @escaping () -> Void"))
        #expect(join.contains("ProfileSummaryRow("))
        #expect(join.contains("onEditProfile: onEditProfile"))
        #expect(join.contains("HoldemAccessibility.Conversation.profileSummary"))
        #expect(join.contains("HoldemAccessibility.Conversation.editProfile"))
        #expect(join.contains("ConversationActionButton(title: \"Join next hand\""))
        #expect(renderer.contains("func showGame(_ state: GameState, hero: String, now: Date,"))
        #expect(renderer.contains("name: String, avatar: String"))
        #expect(renderer.contains("let summary = GamePayload.summary(for: state)"))
        #expect(renderer.contains("JoinGameView(summary: summary,"))
        #expect(renderer.contains("profileName: name"))
        #expect(renderer.contains("profileAvatar: avatar"))
        #expect(renderer.contains("onEditJoinProfile: @escaping () -> Void"))
        #expect(renderer.contains("onEditProfile: onEditJoinProfile"))
        #expect(rendering.contains("name: profile.name"))
        #expect(rendering.contains("avatar: profile.avatar"))
        #expect(rendering.contains("onEditJoinProfile: { [weak self] in self?.renderProfileSetup(isEditingExistingProfile: true) }"))
    }

    @Test("conversation lobby screen shows saved profile before joining table")
    func conversationLobbyScreenShowsSavedProfileBeforeJoiningTable() throws {
        let lobby = try sourceFile("Sources/HoldemUI/LobbyView.swift")
        let renderer = try repoFile("MessagesExtension/TableMessageRenderer.swift")
        let rendering = try repoFile("MessagesExtension/MessagesViewControllerRendering.swift")

        #expect(lobby.contains("profileName: String?"))
        #expect(lobby.contains("profileAvatar: String?"))
        #expect(lobby.contains("onEditProfile: (() -> Void)?"))
        #expect(lobby.contains("profileName: isJoined ? nil : profileName"))
        #expect(lobby.contains("onEditProfile: isJoined ? nil : onEditProfile"))
        #expect(!lobby.contains("Demo-only: edit the saved local profile"))
        #expect(renderer.contains("func showLobby(_ lobby: Lobby, hero: String,\n                   name: String, avatar: String,"))
        #expect(renderer.contains("profileName: name"))
        #expect(renderer.contains("profileAvatar: avatar"))
        #expect(renderer.contains("onEditProfile: onEditProfile"))
        #expect(rendering.contains("tableRenderer.showLobby("))
        #expect(rendering.contains("name: profile.name"))
        #expect(rendering.contains("avatar: profile.avatar"))
        #expect(rendering.contains("onEditProfile: { [weak self] in self?.renderProfileSetup(isEditingExistingProfile: true) }"))
    }

    @Test("profile summary keeps edit as a separate accessible icon action")
    func profileSummaryKeepsEditAsSeparateAccessibleIconAction() throws {
        let source = try sourceFile("Sources/HoldemUI/LobbyActions.swift")
        let accessibility = try sourceFile("Sources/HoldemUI/HoldemAccessibility.swift")

        #expect(source.contains("summaryAccessibilityID = HoldemAccessibility.Lobby.profileSummary"))
        #expect(source.contains("editAccessibilityID = HoldemAccessibility.Lobby.editProfile"))
        #expect(source.contains("ProfileIdentitySummary(name: name,"))
        #expect(source.contains("accessibilityID: summaryAccessibilityID"))
        #expect(source.contains(".accessibilityLabel(\"Playing as \\(name)\")"))
        #expect(source.contains("Image(systemName: \"pencil\")"))
        #expect(source.contains(".accessibilityLabel(\"Edit profile\")"))
        #expect(source.contains("accessibilityIdentifier(editAccessibilityID)"))
        #expect(source.contains(".layoutPriority(1)"))
        #expect(source.contains(".frame(width: 44, height: 44)"))
        #expect(source.contains(".contentShape(Rectangle())"))
        #expect(source.contains(".minimumScaleFactor(0.82)"))
        #expect(source.contains(".allowsTightening(true)"))
        #expect(!source.contains("Button(\"Edit\""))
        #expect(source.contains("RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)"))
        #expect(accessibility.contains("static let profileSummary = \"conversation.profileSummary\""))
        #expect(accessibility.contains("static let editProfile = \"conversation.editProfile\""))
        #expect(!source.contains(".accessibilityElement(children: .combine)"))
    }

    @Test("conversation profile setup expands before showing the form")
    func conversationProfileSetupExpandsBeforeShowingTheForm() throws {
        let renderer = try repoFile("MessagesExtension/TableMessageRenderer.swift")
        let expandRange = renderer.range(of: "requestExpandedPresentation()")
        let setupRange = renderer.range(of: "ProfileSetupView(name: name,")

        #expect(renderer.contains("if presentationStyle() == .compact"))
        #expect(expandRange != nil)
        #expect(setupRange != nil)
        if let expandRange, let setupRange {
            #expect(expandRange.lowerBound < setupRange.lowerBound)
        }
    }

    @Test("conversation preserves profile editing across presentation transitions")
    func conversationPreservesProfileEditingAcrossPresentationTransitions() throws {
        let controller = try repoFile("MessagesExtension/MessagesViewController.swift")
        let rendering = try repoFile("MessagesExtension/MessagesViewControllerRendering.swift")

        #expect(controller.contains("var isEditingProfile = false"))
        #expect(controller.contains("if isEditingProfile || !profile.hasProfile"))
        #expect(controller.contains("renderProfileSetup(isEditingExistingProfile: isEditingProfile)"))
        #expect(rendering.contains("func renderProfileSetup(isEditingExistingProfile: Bool = false)"))
        #expect(rendering.contains("isEditingProfile = isEditingExistingProfile"))
        #expect(rendering.contains("onEditProfile: { [weak self] in self?.renderProfileSetup(isEditingExistingProfile: true) }"))
        #expect(rendering.contains("self?.isEditingProfile = false"))
    }

    @Test("conversation start copy treats profile setup as already complete")
    func conversationStartCopyTreatsProfileSetupAsAlreadyComplete() throws {
        let start = try sourceFile("Sources/HoldemUI/StartGameView.swift")

        #expect(start.contains("Everyone joins with their saved profile and readies up."))
        #expect(!start.contains("Everyone joins, picks a character, and readies up."))
    }

    @Test("message renderer does not invite observers into a finished game")
    func messageRendererDoesNotInviteObserversIntoFinishedGame() throws {
        let renderer = try repoFile("MessagesExtension/TableMessageRenderer.swift")
        let summaryRange = renderer.range(of: "let summary = GamePayload.summary(for: state)")
        let gameOverRange = renderer.range(of: "GameOverView(summary: summary)")
        let joinRange = renderer.range(of: "JoinGameView(summary: summary,")

        #expect(renderer.contains("if state.isGameOver"))
        #expect(renderer.contains("GameOverView(summary: summary)"))
        #expect(renderer.contains("CompactSummaryView(summary: summary"))
        #expect(renderer.components(separatedBy: "GamePayload.summary(for: state)").count == 2)
        #expect(summaryRange != nil)
        #expect(gameOverRange != nil)
        #expect(joinRange != nil)
        if let summaryRange, let gameOverRange, let joinRange {
            #expect(summaryRange.lowerBound < gameOverRange.lowerBound)
            #expect(gameOverRange.lowerBound < joinRange.lowerBound)
        }
    }

    @Test("compact seated game opens expanded table")
    func compactSeatedGameOpensExpandedTable() throws {
        let renderer = try repoFile("MessagesExtension/TableMessageRenderer.swift")
        let compact = try sourceFile("Sources/HoldemUI/CompactSummaryView.swift")
        let seatedRange = try #require(renderer.range(of: "let seated = state.player(id: hero)"))
        let compactRange = try #require(renderer.range(of: "} else if presentationStyle() == .compact {"))
        let tableRange = try #require(renderer.range(of: "PokerTableView("))

        #expect(renderer.contains("CompactSummaryView(summary: summary,"))
        #expect(renderer.contains("onOpen: requestExpandedPresentation"))
        #expect(seatedRange.lowerBound < compactRange.lowerBound)
        #expect(compactRange.lowerBound < tableRange.lowerBound)
        #expect(compact.contains("Button(action: onOpen)"))
        #expect(compact.contains(".buttonStyle(PressableButtonStyle())"))
        #expect(compact.contains("HoldemAccessibility.Conversation.openTable"))
        #expect(compact.contains(".accessibilityLabel(\"Open table. \\(summary)\")"))
    }

    @Test("waiting state and timeout resolution are explicit")
    func waitingStateAndTimeoutResolutionAreExplicit() throws {
        let presentation = try sourceFile("Sources/HoldemUI/PokerTableActionPresentation.swift")
        let actionArea = try sourceFile("Sources/HoldemUI/PokerTableActionArea.swift")
        let rendering = try repoFile("MessagesExtension/MessagesViewControllerRendering.swift")
        let timeout = try sourceFile("Sources/GameCore/GameTimeout.swift")
        let turnClock = try sourceFile("Sources/GameCore/TurnClock.swift")

        #expect(presentation.contains("if isHeroTurn { return .act }"))
        #expect(presentation.contains("return .wait"))
        #expect(presentation.contains("var waitingText: String"))
        #expect(presentation.contains("if let currentPlayer = state.currentPlayer"))
        #expect(presentation.contains("\"Waiting for \\(currentPlayer.name)…\""))
        #expect(presentation.contains("\"Waiting for the next action…\""))
        #expect(presentation.contains("\"You folded — wait for the next hand\""))
        #expect(presentation.contains("func legalActionsForHero() -> LegalActions?"))
        #expect(presentation.contains("guard isHeroTurn, let heroIndex else { return nil }"))
        #expect(actionArea.contains("WaitingBar(text: presentation.waitingText)"))
        #expect(rendering.contains("state.resolveTimeout(now: now)"))
        #expect(timeout.contains("now.timeIntervalSince(started) >= turnDuration"))
        #expect(timeout.contains("apply(legal.canCheck ? .check : .fold"))
        #expect(turnClock.contains("public static let defaultDuration"))
        #expect(turnClock.contains("guard duration.isFinite, duration > 0 else { return defaultDuration }"))
    }

    @Test("deal next hand exposes a stable action identifier")
    func dealNextHandExposesStableActionIdentifier() throws {
        let accessibility = try sourceFile("Sources/HoldemUI/HoldemAccessibility.swift")
        let actionArea = try sourceFile("Sources/HoldemUI/PokerTableActionArea.swift")
        let presentation = try sourceFile("Sources/HoldemUI/PokerTableActionPresentation.swift")

        #expect(accessibility.contains("static let dealNext"))
        #expect(accessibility.contains("\"table.action.dealNext\""))
        #expect(actionArea.contains("accessibilityIdentifier(HoldemAccessibility.Table.dealNext)"))
        #expect(actionArea.contains("ResultBanner(text: \"\\(handWinner.name) wins hand\")"))
        #expect(actionArea.contains("Text(\"Deal next hand\")"))
        #expect(!actionArea.contains("wins hand · Deal next"))
        #expect(actionArea.contains("presentation.canHeroDealNext"))
        #expect(presentation.contains("var canHeroDealNext"))
        #expect(presentation.contains("state.canDealNextHand(actorID: heroID)"))
    }

    @Test("button helpers do not emit empty accessibility identifiers")
    func buttonHelpersDoNotEmitEmptyAccessibilityIdentifiers() throws {
        let actionControls = try sourceFile("Sources/HoldemUI/ActionControls.swift")
        let lobbyButtons = try sourceFile("Sources/HoldemUI/LobbyActionButtons.swift")
        let conversationButton = try sourceFile("Sources/HoldemUI/ConversationActionButton.swift")
        let theme = try sourceFile("Sources/HoldemUI/Theme.swift")

        #expect(theme.contains("static let controlCorner: CGFloat = 8"))
        #expect(actionControls.contains("optionalAccessibilityIdentifier"))
        #expect(lobbyButtons.contains("optionalAccessibilityIdentifier"))
        #expect(lobbyButtons.contains(".stableOneLineText()"))
        #expect(lobbyButtons.contains("RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner).fill(fill)"))
        #expect(!lobbyButtons.contains("ShapeStyleKind"))
        #expect(!lobbyButtons.contains("Capsule().fill(fill)"))
        #expect(conversationButton.contains("optionalAccessibilityIdentifier"))
        #expect(conversationButton.contains(".stableOneLineText()"))
        #expect(conversationButton.contains(".frame(minWidth: 0, maxWidth: .infinity, minHeight: 52)"))
        #expect(conversationButton.contains("RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner).fill(.white)"))
        #expect(!conversationButton.contains("Capsule().fill(.white)"))
        #expect(!actionControls.contains("accessibilityIdentifier(accessibilityID ?? \"\")"))
        #expect(!lobbyButtons.contains("accessibilityIdentifier(accessibilityID ?? \"\")"))
        #expect(!conversationButton.contains("accessibilityIdentifier(accessibilityID ?? \"\")"))
    }

    @Test("live table leave requires confirmation")
    func liveTableLeaveRequiresConfirmation() throws {
        let leaveButton = try sourceFile("Sources/HoldemUI/LeaveTableButton.swift")
        let accessibility = try sourceFile("Sources/HoldemUI/HoldemAccessibility.swift")

        #expect(leaveButton.contains("@State private var isConfirmingLeave"))
        #expect(leaveButton.contains("isConfirmingLeave = true"))
        #expect(leaveButton.contains("withAnimation(.tableSnap)"))
        #expect(leaveButton.contains(".frame(width: 44, height: 44)"))
        #expect(leaveButton.contains("RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)"))
        #expect(leaveButton.contains(".accessibilityValue(isConfirmingLeave ? \"Confirmation open\" : \"Confirmation closed\")"))
        #expect(leaveButton.contains("HoldemAccessibility.Table.cancelLeave"))
        #expect(leaveButton.contains("HoldemAccessibility.Table.confirmLeave"))
        #expect(leaveButton.contains(".stableOneLineText()"))
        #expect(leaveButton.contains("RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner).fill(Theme.controlBackground)"))
        #expect(leaveButton.contains("RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner).fill(Theme.dangerBackground)"))
        #expect(leaveButton.contains("RoundedRectangle(cornerRadius: Theme.Metrics.controlCorner)\n                        .fill(Color.black.opacity(0.86))"))
        #expect(!leaveButton.contains("Capsule()"))
        #expect(leaveButton.contains(".frame(maxWidth: .infinity, alignment: .leading)"))
        #expect(!leaveButton.contains(".fixedSize(horizontal: true, vertical: false)"))
        #expect(accessibility.contains("static let cancelLeave = \"table.leave.cancel\""))
        #expect(accessibility.contains("static let confirmLeave = \"table.leave.confirm\""))
        #expect(leaveButton.contains("Button(\"Leave table\", role: .destructive)"))
        #expect(leaveButton.contains("isConfirmingLeave = false"))
        #expect(leaveButton.contains("action()"))
        #expect(leaveButton.contains("Button(\"Stay\", role: .cancel)"))
    }

    @Test("finished table does not expose a leave action")
    func finishedTableDoesNotExposeLeaveAction() throws {
        let table = try sourceFile("Sources/HoldemUI/PokerTableView.swift")

        #expect(table.contains("private var canLeaveTable: Bool"))
        #expect(table.contains("!state.isGameOver"))
        #expect(table.contains("if let onLeave, canLeaveTable"))
    }

    @Test("seated iMessage table does not plumb unused profile editing")
    func seatedIMessageTableDoesNotPlumbUnusedProfileEditing() throws {
        let renderer = try repoFile("MessagesExtension/TableMessageRenderer.swift")
        let tableRange = try #require(renderer.range(of: "PokerTableView("))
        let joinEditRange = try #require(renderer.range(of: "onEditProfile: onEditJoinProfile"))

        #expect(joinEditRange.lowerBound < tableRange.lowerBound)
        #expect(renderer.contains("onEditJoinProfile: @escaping () -> Void"))
        #expect(!renderer.contains("onEditProfile: @escaping () -> Void,\n                  onAction:"))
    }

    @Test("visible chip amounts use shared formatting")
    func visibleChipAmountsUseSharedFormatting() throws {
        let actionBar = try sourceFile("Sources/HoldemUI/ActionBarView.swift")
        let raisePanel = try sourceFile("Sources/HoldemUI/RaisePanelView.swift")
        let board = try sourceFile("Sources/HoldemUI/BoardView.swift")
        let boardStatus = try sourceFile("Sources/HoldemUI/BoardStatusRow.swift")
        let betChip = try sourceFile("Sources/HoldemUI/BetChip.swift")
        let handStrength = try sourceFile("Sources/HoldemUI/HandStrengthBox.swift")
        let playerSeat = try sourceFile("Sources/HoldemUI/PlayerSeatView.swift")
        let winnings = try sourceFile("Sources/HoldemUI/WinningsFlyView.swift")
        let accessibility = try sourceFile("Sources/HoldemUI/HoldemAccessibility.swift")

        #expect(actionBar.contains("ChipFormatter.string(legal.callAmount)"))
        #expect(raisePanel.contains("ChipFormatter.string(selectedRaiseTo)"))
        #expect(board.contains(".accessibilityLabel(accessibilityLabel)"))
        #expect(board.contains(".accessibilityIdentifier(HoldemAccessibility.Table.board)"))
        #expect(board.contains("return \"Board empty\""))
        #expect(board.contains("board.map(\\.description).joined(separator: \" \")"))
        #expect(accessibility.contains("static let board = \"table.board\""))
        #expect(boardStatus.contains("ChipFormatter.string(pot)"))
        #expect(boardStatus.contains(".accessibilityLabel(\"Pot\")"))
        #expect(boardStatus.contains(".accessibilityValue(ChipFormatter.string(pot))"))
        #expect(boardStatus.contains("HoldemAccessibility.Table.pot"))
        #expect(betChip.contains("ChipFormatter.string(amount)"))
        #expect(handStrength.contains("ChipFormatter.string(stack)"))
        #expect(playerSeat.contains("ChipFormatter.string(player.stack)"))
        #expect(winnings.contains("+\\(ChipFormatter.string(fly.amount))"))
    }

    @Test("table seats expose compact accessibility summaries")
    func tableSeatsExposeCompactAccessibilitySummaries() throws {
        let dock = try sourceFile("Sources/HoldemUI/HeroHandDock.swift")
        let handStrength = try sourceFile("Sources/HoldemUI/HandStrengthBox.swift")
        let playerSeat = try sourceFile("Sources/HoldemUI/PlayerSeatView.swift")

        #expect(playerSeat.contains(".accessibilityElement(children: .ignore)"))
        #expect(playerSeat.contains(".accessibilityLabel(accessibilityLabel)"))
        #expect(playerSeat.contains("private var accessibilityLabel: String"))
        #expect(playerSeat.contains("if isDealer { parts.append(\"dealer\") }"))
        #expect(playerSeat.contains("parts.append(\"stack \\(ChipFormatter.string(player.stack))\")"))
        #expect(playerSeat.contains("if highlightWin { parts.append(\"winner\") }"))
        #expect(playerSeat.contains("if player.bet > 0 { parts.append(\"bet \\(ChipFormatter.string(player.bet))\") }"))
        #expect(playerSeat.contains("if let revealCards, revealCards.count >= 2"))
        #expect(playerSeat.contains("parts.append(\"cards \\(revealCards.map(\\.description).joined(separator: \" \"))\")"))
        #expect(playerSeat.contains("parts.append(\"\\(Int(TurnClock.normalized(turnDuration))) second clock\")"))
        #expect(playerSeat.contains("case .allIn:"))
        #expect(playerSeat.contains("\"all in\""))
        #expect(handStrength.contains(".accessibilityElement(children: .ignore)"))
        #expect(handStrength.contains(".accessibilityLabel(accessibilityLabel)"))
        #expect(handStrength.contains("HoldemAccessibility.Table.heroSeat"))
        #expect(handStrength.contains("let name: String"))
        #expect(handStrength.contains("Text(name)"))
        #expect(handStrength.contains("var parts = [name, \"your seat\", \"stack \\(ChipFormatter.string(stack))\"]"))
        #expect(dock.contains("name: presentation.hero?.name ?? \"Player\""))
        #expect(handStrength.contains("if turnStart != nil"))
        #expect(handStrength.contains("parts.append(\"your turn\")"))
        #expect(handStrength.contains("parts.append(\"\\(Int(TurnClock.normalized(turnDuration))) second clock\")"))
    }

    @Test("visible turn clocks use the shared turn duration contract")
    func visibleTurnClocksUseSharedTurnDurationContract() throws {
        let countdown = try sourceFile("Sources/HoldemUI/CountdownTimer.swift")
        let border = try sourceFile("Sources/HoldemUI/DepletingBorder.swift")
        let handStrength = try sourceFile("Sources/HoldemUI/HandStrengthBox.swift")
        let playerSeat = try sourceFile("Sources/HoldemUI/PlayerSeatView.swift")
        let lobbyStart = try sourceFile("Sources/GameCore/LobbyStart.swift")
        let handLifecycle = try sourceFile("Sources/GameCore/HandLifecycle.swift")

        #expect(countdown.contains("import GameCore"))
        #expect(countdown.contains("TurnClock.normalized(duration)"))
        #expect(!countdown.contains("duration.isFinite && duration > 0 ? duration : 30"))
        #expect(border.contains("import GameCore"))
        #expect(border.contains("TurnClock.normalized(duration)"))
        #expect(!border.contains("duration.isFinite && duration > 0 ? duration : 30"))
        #expect(handStrength.contains("import GameCore"))
        #expect(handStrength.contains("var turnDuration: TimeInterval = TurnClock.defaultDuration"))
        #expect(playerSeat.contains("var turnDuration: TimeInterval = TurnClock.defaultDuration"))
        #expect(playerSeat.contains("turnDuration: TimeInterval = TurnClock.defaultDuration"))
        #expect(playerSeat.contains("Int(TurnClock.normalized(turnDuration))"))
        #expect(lobbyStart.contains("turnDuration: TimeInterval = TurnClock.defaultDuration"))
        #expect(handLifecycle.contains("turnDuration: TimeInterval = TurnClock.defaultDuration"))
        #expect(handStrength.contains("Int(TurnClock.normalized(turnDuration))"))
        #expect(!handStrength.contains("turnDuration: TimeInterval = 30"))
        #expect(!playerSeat.contains("turnDuration: TimeInterval = 30"))
        #expect(!lobbyStart.contains("turnDuration: TimeInterval = 30"))
        #expect(!handLifecycle.contains("turnDuration: TimeInterval = 30"))
    }

    @Test("demo app gates lobby behind a locally saved profile")
    func demoAppGatesLobbyBehindALocallySavedProfile() throws {
        let screen = try sourceFile("Sources/HoldemUI/GameTableScreen.swift")
        let demoLobby = try sourceFile("Sources/HoldemUI/DemoLobby.swift")

        #expect(screen.contains("ProfileStore"))
        #expect(screen.contains("ProfileSetupView"))
        #expect(screen.contains("profile.save"))
        #expect(screen.contains("DemoLobby(lobby: $lobby,"))
        #expect(screen.contains("profileName: profile.name"))
        #expect(screen.contains("profileAvatar: profile.avatar"))
        #expect(screen.contains("onEditProfile: editProfile"))
        #expect(demoLobby.contains("let profileName: String"))
        #expect(demoLobby.contains("let profileAvatar: String"))
        #expect(demoLobby.contains("name: profileName"))
        #expect(demoLobby.contains("avatar: profileAvatar"))
        #expect(demoLobby.contains("static var emptyLobby: Lobby"))
        #expect(demoLobby.contains("Lobby()"))
        #expect(!demoLobby.contains("Lobby(maxPlayers: 6, smallBlind: 5, bigBlind: 10, startingStack: 1000)"))
        #expect(!demoLobby.contains("name: \"You\""))
    }

    @Test("iMessage table settings use core lobby defaults")
    func iMessageTableSettingsUseCoreLobbyDefaults() throws {
        let settings = try repoFile("MessagesExtension/MessageTableSettings.swift")

        #expect(settings.contains("var maxPlayers = Lobby.defaultMaxPlayers"))
        #expect(settings.contains("var startingStack = Lobby.defaultStartingStack"))
        #expect(settings.contains("var smallBlind = Lobby.defaultSmallBlind"))
        #expect(settings.contains("var bigBlind = Lobby.defaultBigBlind"))
        #expect(settings.contains("var turnDuration: TimeInterval = TurnClock.defaultDuration"))
        #expect(settings.contains("func makeLobby() -> Lobby"))
        #expect(!settings.contains("var maxPlayers = TableSize.maxPlayers"))
        #expect(!settings.contains("var startingStack = StartingStack.defaultAmount"))
        #expect(!settings.contains("var smallBlind = 5"))
        #expect(!settings.contains("var bigBlind = 10"))
    }

    @Test("saved profile can be reviewed and edited before joining")
    func savedProfileCanBeReviewedAndEditedBeforeJoining() throws {
        let screen = try sourceFile("Sources/HoldemUI/GameTableScreen.swift")
        let demoLobby = try sourceFile("Sources/HoldemUI/DemoLobby.swift")
        let lobbyView = try sourceFile("Sources/HoldemUI/LobbyView.swift")
        let lobbyActions = try sourceFile("Sources/HoldemUI/LobbyActions.swift")
        let accessibility = try sourceFile("Sources/HoldemUI/HoldemAccessibility.swift")

        #expect(screen.contains("@State private var isEditingProfile = false"))
        #expect(screen.contains("!profile.hasProfile || isEditingProfile"))
        #expect(screen.contains("isEditingProfile = false"))
        #expect(screen.contains("onEditProfile: editProfile"))
        #expect(demoLobby.contains("let onEditProfile: () -> Void"))
        #expect(lobbyView.contains("profileName: String?"))
        #expect(lobbyView.contains("onEditProfile: (() -> Void)?"))
        #expect(lobbyActions.contains("ProfileSummaryRow("))
        #expect(lobbyActions.contains("HoldemAccessibility.Lobby.profileSummary"))
        #expect(lobbyActions.contains("HoldemAccessibility.Lobby.editProfile"))
        #expect(accessibility.contains("static let profileSummary = \"lobby.profileSummary\""))
        #expect(accessibility.contains("static let editProfile = \"lobby.editProfile\""))
    }

    @Test("editing a saved profile preserves the current lobby")
    func editingSavedProfilePreservesCurrentLobby() throws {
        let screen = try sourceFile("Sources/HoldemUI/GameTableScreen.swift")
        let hadProfileRange = screen.range(of: "let hadProfile = profile.hasProfile")
        let saveRange = screen.range(of: "profile.save(name: name, avatar: avatar)")
        let resetRange = screen.range(of: "if !hadProfile {\n            lobby = DemoLobby.emptyLobby\n        }")

        #expect(hadProfileRange != nil)
        #expect(saveRange != nil)
        #expect(resetRange != nil)
        if let hadProfileRange, let saveRange, let resetRange {
            #expect(hadProfileRange.lowerBound < saveRange.lowerBound)
            #expect(saveRange.lowerBound < resetRange.lowerBound)
        }
    }

    @Test("profile storage is independent from app launch arguments")
    func profileStorageIsIndependentFromAppLaunchArguments() throws {
        let store = try sourceFile("Sources/HoldemUI/ProfileStore.swift")
        let screen = try sourceFile("Sources/HoldemUI/GameTableScreen.swift")

        #expect(!store.contains("ProcessInfo"))
        #expect(store.contains("resetProfile: Bool = false"))
        #expect(screen.contains("ProcessInfo.processInfo.arguments.contains(\"-holdemResetProfile\")"))
        #expect(screen.contains("ProfileStore(resetProfile: resetProfile)"))
    }

    @Test("message action rejections are presented with reasons")
    func messageActionRejectionsArePresentedWithReasons() throws {
        let staleView = try sourceFile("Sources/HoldemUI/StaleTableView.swift")
        let committer = try repoFile("MessagesExtension/TableMessageCommitter.swift")
        let sending = try repoFile("MessagesExtension/MessagesViewControllerSending.swift")

        #expect(staleView.contains("case rejectedAction(TableOperationRejection? = nil)"))
        #expect(staleView.contains("private static func rejectionGuidance"))
        #expect(staleView.contains("case .notActorTurn"))
        #expect(staleView.contains("\"It is not your turn.\""))
        #expect(staleView.contains("case .duplicateOperation"))
        #expect(staleView.contains("\"That action was already applied. Open the newest River bubble to keep playing.\""))
        #expect(staleView.contains("case .wrongTable"))
        #expect(staleView.contains("\"That action belongs to another table. Open the matching River bubble to keep playing.\""))
        #expect(staleView.contains("case .wrongPhase"))
        #expect(staleView.contains("\"That action does not match the current table state. Open the newest River bubble and try again.\""))
        #expect(committer.contains("case rejected(TableMessage, TableOperationRejection)"))
        #expect(committer.contains("case unchanged"))
        #expect(committer.contains("case .unchanged:"))
        #expect(committer.contains("case .rejected(let reason):"))
        #expect(committer.contains("return .rejected(message, reason)"))
        #expect(sending.contains("case .rejected(let message, let reason):"))
        #expect(sending.contains("case .unchanged:"))
        #expect(sending.contains("context: .rejectedAction(reason)"))
        #expect(!sending.contains("case .rejected:\n            render(conversation: conversation)"))
    }

    @Test("payload encoding failures are presented instead of silently rerendering")
    func payloadEncodingFailuresArePresentedInsteadOfSilentlyRerendering() throws {
        let staleView = try sourceFile("Sources/HoldemUI/StaleTableView.swift")
        let sending = try repoFile("MessagesExtension/MessagesViewControllerSending.swift")

        #expect(staleView.contains("case encodingFailed"))
        #expect(staleView.contains("\"Could not send table\""))
        #expect(staleView.contains("\"The table state is too large or invalid. Open the newest River bubble and try again.\""))
        #expect(sending.contains("case .encodingFailed(let error):"))
        #expect(sending.contains("MessagePayloads.selectedTableMessage(in: conversation)"))
        #expect(sending.contains("tableRenderer.showStale(message, context: .encodingFailed)"))
        #expect(!sending.contains("case .encodingFailed(let error):\n            NSLog(\"River payload encode failed: \\(error.localizedDescription)\")\n            render(conversation: conversation)"))
    }

    @Test("invalid selected message payloads are not treated as missing games")
    func invalidSelectedMessagePayloadsAreNotTreatedAsMissingGames() throws {
        let payloads = try repoFile("MessagesExtension/MessagePayloads.swift")
        let renderer = try repoFile("MessagesExtension/TableMessageRenderer.swift")
        let rendering = try repoFile("MessagesExtension/MessagesViewControllerRendering.swift")
        let sending = try repoFile("MessagesExtension/MessagesViewControllerSending.swift")
        let staleView = try sourceFile("Sources/HoldemUI/StaleTableView.swift")
        let selectedRange = rendering.range(of: "let selectedMessage = MessagePayloads.selectedTableMessage(in: conversation)")
        let profileRange = rendering.range(of: "guard profile.hasProfile else")
        let invalidRange = rendering.range(of: "case .invalidPayload:")

        #expect(payloads.contains("enum SelectedTableMessage"))
        #expect(payloads.contains("case none"))
        #expect(payloads.contains("case invalidPayload"))
        #expect(payloads.contains("case message(TableMessage)"))
        #expect(payloads.contains("return .invalidPayload"))
        #expect(!payloads.contains("catch {\n            return nil\n        }"))
        #expect(renderer.contains("func showInvalidPayload()"))
        #expect(renderer.contains("context: .invalidPayload"))
        #expect(rendering.contains("case .invalidPayload:"))
        #expect(rendering.contains("tableRenderer.showInvalidPayload()"))
        #expect(rendering.contains("return"))
        #expect(selectedRange != nil)
        #expect(profileRange != nil)
        #expect(invalidRange != nil)
        if let selectedRange, let profileRange, let invalidRange {
            #expect(selectedRange.lowerBound < profileRange.lowerBound)
            #expect(invalidRange.lowerBound < profileRange.lowerBound)
        }
        #expect(sending.contains("case .invalidPayload:"))
        #expect(sending.contains("tableRenderer.showInvalidPayload()"))
        #expect(staleView.contains("case invalidPayload"))
        #expect(staleView.contains("\"Could not open table\""))
        #expect(staleView.contains("HoldemAccessibility.Conversation.recovery"))
        #expect(staleView.contains(".fixedSize(horizontal: false, vertical: true)"))
    }

    @Test("outgoing iMessage bubbles identify the product and table state")
    func outgoingIMessageBubblesIdentifyProductAndTableState() throws {
        let payloads = try repoFile("MessagesExtension/MessagePayloads.swift")

        #expect(payloads.contains("let summary = GamePayload.summary(for: message)"))
        #expect(payloads.contains("layout.caption = \"River\""))
        #expect(payloads.contains("layout.subcaption = summary"))
        #expect(payloads.contains("messageView.summaryText = \"River: \\(summary)\""))
        #expect(payloads.contains("messageView.url = try GamePayload.encodeToURL(message)"))
    }

    @Test("async message send failures are presented")
    func asyncMessageSendFailuresArePresented() throws {
        let staleView = try sourceFile("Sources/HoldemUI/StaleTableView.swift")
        let sender = try repoFile("MessagesExtension/MessageSender.swift")
        let controller = try repoFile("MessagesExtension/MessagesViewController.swift")
        let sending = try repoFile("MessagesExtension/MessagesViewControllerSending.swift")

        #expect(staleView.contains("case sendFailed"))
        #expect(staleView.contains("\"Could not send action\""))
        #expect(staleView.contains("\"Messages could not send that update. Open the newest River bubble and try again.\""))
        #expect(sender.contains("private let onSendSuccess: (TableMessage) -> Void"))
        #expect(sender.contains("private let onSendFailure: (TableMessage, Error) -> Void"))
        #expect(sender.contains("DispatchQueue.main.async"))
        #expect(sender.contains("self.onSendFailure(message, error)"))
        #expect(controller.contains("onSendSuccess: { [weak self] _ in"))
        #expect(controller.contains("self?.dismiss()"))
        #expect(controller.contains("onSendFailure: { [weak self] message, _ in"))
        #expect(controller.contains("self?.tableRenderer.showStale(message, context: .sendFailed)"))
        #expect(sending.contains("case .sent:\n            break"))
        #expect(sending.contains("case .unchanged:\n            dismiss()"))
        #expect(!sending.contains("case .sent:\n            dismiss()"))
    }

    @Test("message sender remembers revisions only after successful send")
    func messageSenderRemembersRevisionsOnlyAfterSuccessfulSend() throws {
        let sender = try repoFile("MessagesExtension/MessageSender.swift")
        let sendRange = try #require(sender.range(of: "conversation.send(outgoing) { error in"))
        let rememberRange = try #require(sender.range(of: "revisionStore.remember(message.revision)"))
        let successCallbackRange = try #require(sender.range(of: "self.onSendSuccess(message)"))
        let successDispatchRange = try #require(sender.range(of: "} else {\n                DispatchQueue.main.async {"))

        #expect(rememberRange.lowerBound > sendRange.lowerBound)
        #expect(successDispatchRange.lowerBound < rememberRange.lowerBound)
        #expect(rememberRange.lowerBound < successCallbackRange.lowerBound)
        #expect(sender.contains("if let error {"))
        #expect(sender.contains("} else {\n                DispatchQueue.main.async {\n                    self.revisionStore.remember(message.revision)\n                    self.onSendSuccess(message)\n                }\n            }"))
    }

    @Test("latest revision store persists deterministic revision order")
    func latestRevisionStorePersistsDeterministicRevisionOrder() throws {
        let store = try repoFile("MessagesExtension/LatestRevisionStore.swift")
        let tracker = try sourceFile("Sources/GameCore/TableRevisionTracker.swift")

        #expect(tracker.contains("public var latestRevisions: [TableRevision]"))
        #expect(tracker.contains("latestByTableID.values.sorted { $0.tableID < $1.tableID }"))
        #expect(store.contains("let revisions = tracker.latestRevisions"))
        #expect(!store.contains("Array(tracker.latestByTableID.values)"))
    }

    private func sourceFile(_ relativePath: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let packageRoot = testsDirectory.deletingLastPathComponent()
        let fileURL = packageRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    private func repoFile(_ relativePath: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let packageRoot = testsDirectory.deletingLastPathComponent()
        let repoRoot = packageRoot.deletingLastPathComponent()
        let fileURL = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }
}
