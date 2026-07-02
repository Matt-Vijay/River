import XCTest

final class RiverInteractionTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-holdemResetProfile"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    func testLobbyToHandRaisePanelAndFoldButtonFlow() {
        XCTAssertFalse(app.buttons["lobby.addTestPlayer"].waitForExistence(timeout: 1))

        let nameField = textField("profile.name", timeout: 5)
        nameField.tap()
        nameField.typeText("Maverick")

        let foxAvatar = button("profile.avatar.9")
        foxAvatar.tap()
        assertLabel(foxAvatar, contains: "Selected character")
        button("profile.save").tap()

        let profileSummary = anyElement("lobby.profileSummary", timeout: 3)
        assertLabel(profileSummary, contains: "Maverick")

        button("lobby.editProfile").tap()

        XCTAssertTrue(nameField.waitForExistence(timeout: defaultTimeout))
        XCTAssertEqual(nameField.value as? String, "Maverick")

        button("profile.cancel").tap()
        XCTAssertTrue(profileSummary.waitForExistence(timeout: defaultTimeout))
        button("lobby.editProfile").tap()

        XCTAssertTrue(nameField.waitForExistence(timeout: defaultTimeout))
        XCTAssertEqual(nameField.value as? String, "Maverick")
        button("profile.save").tap()

        button("lobby.join", timeout: 3).tap()
        XCTAssertTrue(button("lobby.ready").exists)
        XCTAssertFalse(app.buttons["lobby.editProfile"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.descendants(matching: .any)["lobby.profileSummary"].exists)

        let addTestPlayer = button("lobby.addTestPlayer")
        assertLabel(addTestPlayer, equals: "Add player")
        addTestPlayer.tap()

        button("lobby.ready").tap()

        let fold = button("table.action.fold", timeout: 5)

        button("table.leave").tap()

        button("table.leave.cancel").tap()
        XCTAssertTrue(fold.waitForExistence(timeout: defaultTimeout))

        let raise = app.buttons["table.action.raise.expand"]
        XCTAssertTrue(raise.exists)
        raise.tap()

        let raiseSlider = app.sliders["table.raise.slider"]
        XCTAssertTrue(raiseSlider.waitForExistence(timeout: defaultTimeout))
        assertRaiseSelectionAfterAdjusting(raiseSlider, to: 0)
        assertRaiseSelectionAfterAdjusting(raiseSlider, to: 1)
        raiseSlider.adjust(toNormalizedSliderPosition: 0.85)
        assertLabel(button("table.raise.submit"), contains: "raise to")

        button("table.raise.preset.1bb").tap()
        assertLabel(button("table.raise.submit"), contains: "raise to")

        button("table.raise.preset.pot").tap()
        assertLabel(button("table.raise.submit"), contains: "raise to")

        button("table.raise.close").tap()

        XCTAssertTrue(raise.waitForExistence(timeout: defaultTimeout))
        raise.tap()

        button("table.raise.preset.halfPot").tap()

        let submitRaise = button("table.raise.submit")
        assertLabel(submitRaise, contains: "raise to")
        submitRaise.tap()

        XCTAssertTrue(fold.waitForExistence(timeout: defaultTimeout))
        fold.tap()

        let dealNext = button("table.action.dealNext", timeout: 3)
        assertLabel(anyElement("table.result"), contains: "wins")
        assertLabel(dealNext, equals: "Deal next hand")
        dealNext.tap()

        _ = anyElement("table.holeCards", timeout: 3)
        assertLabel(anyElement("table.board"), equals: "Board empty")
        XCTAssertFalse(dealNext.exists)
    }

    func testProfileSaveGateAndLocalPersistence() {
        let nameField = textField("profile.name", timeout: 5)

        let saveProfile = app.buttons["profile.save"]
        XCTAssertTrue(saveProfile.exists)
        XCTAssertFalse(saveProfile.isEnabled)

        let oversizedName = "ABCDEFGHIJKLMNOPQRSTUVWXYZZZ"
        let cappedName = "ABCDEFGHIJKLMNOPQRSTUVWX"
        nameField.tap()
        nameField.typeText(oversizedName)
        waitForValue(nameField, equals: cappedName)
        XCTAssertTrue(saveProfile.isEnabled)
        saveProfile.tap()

        assertLabel(anyElement("lobby.profileSummary", timeout: 3), contains: cappedName)

        app.terminate()
        app.launchArguments = []
        app.launch()

        assertLabel(anyElement("lobby.profileSummary", timeout: 3), contains: cappedName)
        XCTAssertFalse(app.textFields["profile.name"].exists)
    }

    func testProfileRejectsWhitespaceOnlyHandle() {
        let nameField = textField("profile.name", timeout: 5)
        let saveProfile = app.buttons["profile.save"]
        XCTAssertFalse(saveProfile.isEnabled)

        nameField.tap()
        nameField.typeText("   ")

        XCTAssertFalse(saveProfile.isEnabled)
        XCTAssertFalse(app.buttons["lobby.join"].waitForExistence(timeout: 1))
    }

    func testLobbyLeaveRejoinAndTableObservability() {
        saveProfile(named: "River")

        let join = button("lobby.join", timeout: 3)
        join.tap()

        button("lobby.leave").tap()
        XCTAssertTrue(join.waitForExistence(timeout: defaultTimeout))
        assertLabel(anyElement("lobby.profileSummary"), contains: "River")
        XCTAssertTrue(app.buttons["lobby.editProfile"].exists)

        join.tap()
        button("lobby.addTestPlayer").tap()

        button("lobby.ready").tap()

        let pot = anyElement("table.pot", timeout: 5)
        XCTAssertFalse(pot.label.isEmpty)

        assertLabel(anyElement("table.heroSeat"), contains: "River")
        assertLabel(anyElement("table.heroSeat"), contains: "stack")

        assertLabel(anyElement("table.holeCards"), contains: "hole cards")
    }

    func testCheckCallProgressesToBoardCardsAndWaitingStates() {
        saveProfile(named: "Caller")

        button("lobby.join", timeout: 3).tap()
        button("lobby.addTestPlayer").tap()
        button("lobby.ready").tap()

        let firstCall = button("table.action.call", timeout: 5)
        assertLabel(firstCall, contains: "call")
        firstCall.tap()

        button("table.action.check", timeout: 3).tap()

        let pot = anyElement("table.pot", timeout: 3)
        XCTAssertFalse(pot.label.isEmpty)

        waitForBoardCardCount(3)

        tapCheckOrCall()
        tapCheckOrCall()
        waitForBoardCardCount(4)

        tapCheckOrCall()
        tapCheckOrCall()
        waitForBoardCardCount(5)

        tapCheckOrCall()
        tapCheckOrCall()

        assertLabel(anyElement("table.result", timeout: 3), contains: "wins")
        assertLabel(button("table.action.dealNext"), equals: "Deal next hand")
        assertLabel(anyElement("table.heroSeat"), contains: "stack")
    }

    func testLeaveConfirmationEndsHeadsUpTable() {
        saveProfile(named: "Leaver")

        button("lobby.join", timeout: 3).tap()
        button("lobby.addTestPlayer").tap()
        button("lobby.ready").tap()

        button("table.leave", timeout: 5).tap()
        button("table.leave.confirm").tap()

        assertLabel(anyElement("table.result", timeout: 3), contains: "wins")
        assertLabel(anyElement("table.result"), contains: "game")
        XCTAssertFalse(app.buttons["table.leave"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.buttons["table.action.dealNext"].exists)
    }

    private func saveProfile(named name: String) {
        let nameField = textField("profile.name", timeout: 5)
        nameField.tap()
        nameField.typeText(name)

        let saveProfile = button("profile.save")
        XCTAssertTrue(saveProfile.isEnabled)
        saveProfile.tap()

        assertLabel(anyElement("lobby.profileSummary", timeout: 3), contains: name)
    }

    private var defaultTimeout: TimeInterval { 2 }

    private func button(_ identifier: String,
                        timeout: TimeInterval? = nil,
                        file: StaticString = #filePath,
                        line: UInt = #line) -> XCUIElement {
        let element = app.buttons[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout ?? defaultTimeout),
                      "Missing button \(identifier)", file: file, line: line)
        return element
    }

    private func textField(_ identifier: String,
                           timeout: TimeInterval? = nil,
                           file: StaticString = #filePath,
                           line: UInt = #line) -> XCUIElement {
        let element = app.textFields[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout ?? defaultTimeout),
                      "Missing text field \(identifier)", file: file, line: line)
        return element
    }

    private func anyElement(_ identifier: String,
                            timeout: TimeInterval? = nil,
                            file: StaticString = #filePath,
                            line: UInt = #line) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout ?? defaultTimeout),
                      "Missing element \(identifier)", file: file, line: line)
        return element
    }

    private func assertLabel(_ element: XCUIElement,
                             contains expectedText: String,
                             file: StaticString = #filePath,
                             line: UInt = #line) {
        XCTAssertTrue(element.label.localizedCaseInsensitiveContains(expectedText),
                      "Expected '\(element.label)' to contain '\(expectedText)'",
                      file: file,
                      line: line)
    }

    private func assertLabel(_ element: XCUIElement,
                             equals expectedText: String,
                             file: StaticString = #filePath,
                             line: UInt = #line) {
        XCTAssertEqual(element.label, expectedText, file: file, line: line)
    }

    private func tapCheckOrCall(file: StaticString = #filePath, line: UInt = #line) {
        let check = app.buttons["table.action.check"]
        if check.waitForExistence(timeout: defaultTimeout) {
            check.tap()
            return
        }

        let call = app.buttons["table.action.call"]
        XCTAssertTrue(call.waitForExistence(timeout: defaultTimeout),
                      "Missing check/call action", file: file, line: line)
        call.tap()
    }

    private func assertRaiseSelectionAfterAdjusting(_ slider: XCUIElement,
                                                    to normalizedPosition: CGFloat,
                                                    file: StaticString = #filePath,
                                                    line: UInt = #line) {
        slider.adjust(toNormalizedSliderPosition: normalizedPosition)

        assertLabel(button("table.raise.submit", file: file, line: line),
                    contains: "raise to",
                    file: file,
                    line: line)

        let valueText = slider.value as? String ?? ""
        XCTAssertFalse(valueText.isEmpty,
                       "Expected raise slider to expose the selected raise amount",
                       file: file,
                       line: line)
    }

    private func waitForBoardCardCount(_ expectedCount: Int,
                                       file: StaticString = #filePath,
                                       line: UInt = #line) {
        let board = anyElement("table.board", timeout: 3, file: file, line: line)
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { element, _ in
                guard let element = element as? XCUIElement else { return false }
                return self.boardCardCount(in: element.label) == expectedCount
            },
            object: board
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: defaultTimeout)
        XCTAssertEqual(result, .completed,
                       "Expected board card count \(expectedCount), got '\(board.label)'",
                       file: file, line: line)
    }

    private func boardCardCount(in label: String) -> Int {
        guard label.hasPrefix("Board: ") else { return 0 }
        return label
            .dropFirst("Board: ".count)
            .split(separator: " ")
            .count
    }

    private func waitForValue(_ element: XCUIElement,
                              equals expectedValue: String,
                              timeout: TimeInterval? = nil,
                              file: StaticString = #filePath,
                              line: UInt = #line) {
        let predicate = NSPredicate(format: "value == %@", expectedValue)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout ?? defaultTimeout)
        XCTAssertEqual(result, .completed,
                       "Expected value '\(String(describing: element.value))' to equal '\(expectedValue)'",
                       file: file,
                       line: line)
    }
}
