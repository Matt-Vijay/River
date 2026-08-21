import XCTest

final class RiverMessagesInteractionTests: XCTestCase {
    private let messages = XCUIApplication(bundleIdentifier: "com.apple.MobileSMS")

    override func setUpWithError() throws {
        continueAfterFailure = false
        messages.launch()
    }

    func testOpeningRiverSendsTableMessage() {
        openFirstConversation()
        openRiver()
        configureProfileIfNeeded()

        XCTAssertFalse(messages.buttons["conversation.startTable"].exists)
        let sendTable = messages.buttons["conversation.sendTable"]
        XCTAssertTrue(sendTable.waitForExistence(timeout: 5))
        sendTable.tap()
        XCTAssertTrue(sendTable.waitForNonExistence(timeout: 5),
                      "Tapping the table card must send it and close the extension.")

        let lobbyPredicate = NSPredicate(
            format: "label CONTAINS %@ AND label CONTAINS %@",
            "seated",
            "Open table"
        )
        let transcript = messages.collectionViews["TranscriptCollectionView"]
        let lobbyBubbles = transcript.links.matching(lobbyPredicate)

        if !lobbyBubbles.firstMatch.waitForExistence(timeout: 3) {
            sendStagedTableIfPresent(matching: lobbyPredicate)
        }
        XCTAssertTrue(lobbyBubbles.firstMatch.waitForExistence(timeout: 8))
        let lobbyBubble = lobbyBubbles.allElementsBoundByIndex.last ?? lobbyBubbles.firstMatch
        lobbyBubble.tap()

        let startGame = messages.buttons["lobby.startGame"]
        XCTAssertTrue(startGame.waitForExistence(timeout: 5))
        XCTAssertFalse(startGame.isEnabled)
        let leave = messages.buttons["lobby.leave"]
        XCTAssertTrue(leave.exists)
        XCTAssertFalse(messages.buttons["lobby.addPlayer"].exists)

        leave.tap()
        let cancelLeave = messages.buttons
            .matching(identifier: "lobby.leave.cancel")
            .firstMatch
        XCTAssertTrue(cancelLeave.waitForExistence(timeout: 2))
        XCTAssertTrue(messages.buttons["lobby.leave.confirm"].exists)
        cancelLeave.tap()
        XCTAssertTrue(cancelLeave.waitForNonExistence(timeout: 2))

        leave.tap()
        let confirmLeave = messages.buttons
            .matching(identifier: "lobby.leave.confirm")
            .firstMatch
        XCTAssertTrue(confirmLeave.waitForExistence(timeout: 2))
        confirmLeave.tap()
        XCTAssertTrue(startGame.waitForNonExistence(timeout: 5),
                      "Leaving must send the updated table and close the extension.")

        let emptyLobbyPredicate = NSPredicate(
            format: "label CONTAINS %@ AND label CONTAINS %@",
            "0/6 seated",
            "Open table"
        )
        sendStagedTableIfPresent(matching: emptyLobbyPredicate)
        let emptyLobbyBubbles = transcript.links.matching(emptyLobbyPredicate)
        XCTAssertTrue(emptyLobbyBubbles.firstMatch.waitForExistence(timeout: 8))
        let emptyLobby = emptyLobbyBubbles.allElementsBoundByIndex.last
            ?? emptyLobbyBubbles.firstMatch
        emptyLobby.tap()

        XCTAssertTrue(startGame.waitForExistence(timeout: 5))
        XCTAssertFalse(startGame.isEnabled)
        XCTAssertTrue(leave.waitForExistence(timeout: 5),
                      "Selecting a table must automatically seat the local participant.")
    }

    private func openFirstConversation() {
        let rows = messages.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "+1 (")
        )
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 3))
        rows.firstMatch.tap()
        XCTAssertTrue(messages.textFields["messageBodyField"].waitForExistence(timeout: 3))
    }

    private func sendStagedTableIfPresent(matching predicate: NSPredicate) {
        let composer = messages.otherElements["MessageEntryView"]
        let stagedTable = composer.descendants(matching: .link)
            .matching(predicate)
            .firstMatch
        guard stagedTable.waitForExistence(timeout: 2) else { return }

        let hostSend = composer.buttons["sendButton"]
        XCTAssertTrue(hostSend.isEnabled)
        hostSend.tap()
    }

    private func openRiver() {
        let addButton = messages.buttons["add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()

        for _ in 0..<4 {
            if let river = hittableRiverLabel() {
                river.tap()
                XCTAssertTrue(messages.popovers.firstMatch.waitForNonExistence(timeout: 3))
                return
            }
            let start = messages.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92))
            let end = messages.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.66))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTFail("River must be available in the Messages app drawer.")
    }

    private func hittableRiverLabel() -> XCUIElement? {
        messages.popovers.staticTexts.matching(
            NSPredicate(format: "label == %@", "River")
        ).allElementsBoundByIndex.first(where: \.isHittable)
    }

    private func configureProfileIfNeeded() {
        let nameField = messages.textFields["profile.name"]
        guard nameField.waitForExistence(timeout: 2) else { return }
        replaceText(in: nameField, with: "River Starter")

        let saveButton = messages.buttons["profile.save"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()
    }

    private func replaceText(in field: XCUIElement, with replacement: String) {
        XCTAssertTrue(field.isHittable, "Profile handle must be reachable in the Messages host.")
        field.tap()
        XCTAssertTrue(messages.keyboards.firstMatch.waitForExistence(timeout: 2),
                      "Tapping the profile handle must focus it and present the keyboard.")
        if let current = field.value as? String {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                                  count: current.count))
        }
        field.typeText(replacement)
    }

}
