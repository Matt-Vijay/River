import XCTest

final class RiverInteractionTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-riverResetProfile"]
        app.launch()
    }

    func testLobbyToRaiseAndAllInActionFlow() {
        saveProfile(named: "Maverick")

        let startGame = button("lobby.startGame", timeout: 3)
        XCTAssertFalse(startGame.isEnabled)

        let addPlayer = button("lobby.addPlayer")
        assertLabel(addPlayer, equals: "Add player")
        addPlayer.tap()
        button("lobby.addPlayer").tap()
        XCTAssertTrue(startGame.isEnabled)
        startGame.tap()

        revealCurrentHand(expectedPlayer: "Maverick")
        let fold = button("table.action.fold", timeout: 5)
        assertLabel(anyElement("table.heroSeat"), contains: "Maverick")

        button("table.leave").tap()
        XCTAssertTrue(app.staticTexts[
            "Your current hand will be folded. You will sit out future hands."
        ].exists)
        button(labeled: "Stay").tap()
        XCTAssertTrue(fold.waitForExistence(timeout: defaultTimeout))

        let raise = button("table.action.raise.expand")
        let heroSeatBeforeRaise = anyElement("table.heroSeat").frame
        raise.tap()

        let raiseSlider = app.sliders["table.raise.slider"]
        XCTAssertTrue(raiseSlider.waitForExistence(timeout: defaultTimeout))
        XCTAssertEqual(anyElement("table.heroSeat").frame.minY,
                       heroSeatBeforeRaise.minY,
                       accuracy: 1,
                       "Opening raise options must not shift the hero hand")
        XCTAssertEqual(raiseAmountAfterAdjusting(raiseSlider, to: 0), 20)
        XCTAssertGreaterThan(raiseAmountAfterAdjusting(raiseSlider, to: 1), 900)
        raiseSlider.adjust(toNormalizedSliderPosition: 0.85)
        let adjustedLabel = button("table.raise.submit").label

        button("table.raise.preset.1bb").tap()
        XCTAssertNotEqual(button("table.raise.submit").label, adjustedLabel)

        button("table.raise.preset.pot").tap()
        assertLabel(button("table.raise.submit"), equals: "Raise to 35")

        button("table.raise.close").tap()

        let reopenedRaise = button("table.action.raise.expand")
        waitUntilHittable(reopenedRaise)
        reopenedRaise.tap()

        button("table.raise.preset.allIn").tap()
        let submitRaise = button("table.raise.submit")
        assertLabel(submitRaise, equals: "Raise to 1,000")
        submitRaise.tap()

        revealCurrentHand(expectedPlayer: "Guest 1")
        let allInCall = button("table.action.call", timeout: 3)
        assertLabel(allInCall, contains: "995")
        allInCall.tap()

        revealCurrentHand(expectedPlayer: "Guest 2")
        XCTAssertTrue(fold.waitForExistence(timeout: defaultTimeout))
        fold.tap()

        assertLabel(anyElement("table.result", timeout: 3), contains: "won")
    }

    func testProfileSaveGateAndLocalPersistence() {
        XCTAssertTrue(app.staticTexts["Create profile"].waitForExistence(timeout: defaultTimeout))
        let nameField = textField("profile.name", timeout: 5)

        let saveProfile = app.buttons["profile.save"]
        XCTAssertTrue(saveProfile.exists)
        XCTAssertFalse(saveProfile.isEnabled)

        let oversizedName = "ABCDEFGHIJKLMNOPQRSTUVWXYZZZ"
        let cappedName = "ABCDEFGHIJKLMNOPQRSTUVWX"
        nameField.tap()
        nameField.typeText(oversizedName)
        waitForValue(nameField, equals: cappedName)

        let foxAvatar = button("profile.avatar.9")
        foxAvatar.tap()
        assertLabel(foxAvatar, contains: "Selected character")

        XCTAssertTrue(saveProfile.isEnabled)
        saveProfile.tap()

        assertLabel(anyElement("lobby.localSeat", timeout: 3), contains: cappedName)

        app.terminate()
        app.launchArguments = []
        app.launch()

        assertLabel(anyElement("lobby.localSeat", timeout: 3), contains: cappedName)
        XCTAssertFalse(app.textFields["profile.name"].exists)
        XCTAssertFalse(app.buttons["lobby.editProfile"].exists)
    }

    func testLobbyLeaveIsConfirmedAndNeverStartsTheGame() {
        saveProfile(named: "River")

        button("lobby.leave").tap()
        XCTAssertTrue(
            app.staticTexts["You will give up your seat in the lobby."]
                .waitForExistence(timeout: defaultTimeout)
        )
        button(labeled: "Stay").tap()
        XCTAssertTrue(button("lobby.startGame").exists)
        button("lobby.leave").tap()
        button("lobby.leave.confirm").tap()
        XCTAssertFalse(app.buttons["lobby.leave"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["lobby.localSeat"].exists)
        XCTAssertFalse(button("lobby.startGame").isEnabled)
        XCTAssertFalse(app.buttons["table.action.fold"].exists)
    }

    private func saveProfile(named name: String) {
        let nameField = textField("profile.name", timeout: 5)
        nameField.tap()
        nameField.typeText(name)

        let saveProfile = button("profile.save")
        XCTAssertTrue(saveProfile.isEnabled)
        saveProfile.tap()

        assertLabel(anyElement("lobby.localSeat", timeout: 3), contains: name)
    }

    private var defaultTimeout: TimeInterval { 2 }

    private func button(_ identifier: String,
                        timeout: TimeInterval? = nil,
                        file: StaticString = #filePath,
                        line: UInt = #line) -> XCUIElement {
        let element = app.buttons.matching(identifier: identifier).firstMatch
        return require(element, timeout: timeout,
                       message: "Missing button \(identifier)", file: file, line: line)
    }

    private func button(labeled label: String,
                        timeout: TimeInterval? = nil,
                        file: StaticString = #filePath,
        line: UInt = #line) -> XCUIElement {
        let element = app.buttons[label].firstMatch
        return require(element, timeout: timeout,
                       message: "Missing button labeled \(label)", file: file, line: line)
    }

    private func waitUntilHittable(_ element: XCUIElement,
                                   file: StaticString = #filePath,
                                   line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: defaultTimeout),
                       .completed, "Element never became hittable", file: file, line: line)
    }

    private func textField(_ identifier: String,
                           timeout: TimeInterval? = nil,
                           file: StaticString = #filePath,
        line: UInt = #line) -> XCUIElement {
        let element = app.textFields[identifier]
        return require(element, timeout: timeout,
                       message: "Missing text field \(identifier)", file: file, line: line)
    }

    private func anyElement(_ identifier: String,
                            timeout: TimeInterval? = nil,
                            file: StaticString = #filePath,
        line: UInt = #line) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier]
        return require(element, timeout: timeout,
                       message: "Missing element \(identifier)", file: file, line: line)
    }

    private func require(_ element: XCUIElement,
                         timeout: TimeInterval?,
                         message: String,
                         file: StaticString,
                         line: UInt) -> XCUIElement {
        XCTAssertTrue(element.exists || element.waitForExistence(timeout: timeout ?? defaultTimeout),
                      message, file: file, line: line)
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

    private func revealCurrentHand(expectedPlayer: String? = nil,
                                   file: StaticString = #filePath,
                                   line: UInt = #line) {
        let handoff = anyElement("table.handoff", timeout: 3, file: file, line: line)
        if let expectedPlayer {
            assertLabel(handoff, contains: expectedPlayer, file: file, line: line)
        }
        XCTAssertFalse(app.descendants(matching: .any)["table.holeCards"].exists,
                       "Hole cards must remain absent until the current player reveals",
                       file: file,
                       line: line)
        XCTAssertTrue(app.buttons["table.leave"].exists,
                      "Players must be able to leave without revealing a hand",
                      file: file,
                      line: line)
        let reveal = button("table.handoff.reveal", file: file, line: line)
        waitUntilHittable(reveal, file: file, line: line)
        reveal.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["table.holeCards"]
                .waitForExistence(timeout: defaultTimeout),
            "Hole cards did not appear after the handoff reveal",
            file: file,
            line: line
        )
    }

    private func raiseAmountAfterAdjusting(_ slider: XCUIElement,
                                           to normalizedPosition: CGFloat,
                                           file: StaticString = #filePath,
                                           line: UInt = #line) -> Int {
        slider.adjust(toNormalizedSliderPosition: normalizedPosition)

        let label = button("table.raise.submit", file: file, line: line).label
        let amountText = label
            .replacingOccurrences(of: "Raise to ", with: "")
            .replacingOccurrences(of: ",", with: "")
        guard let amount = Int(amountText) else {
            XCTFail("Expected numeric raise label, got '\(label)'", file: file, line: line)
            return -1
        }

        let valueText = slider.value as? String ?? ""
        XCTAssertFalse(valueText.isEmpty,
                       "Expected raise slider to expose the selected raise amount",
                       file: file,
                       line: line)
        return amount
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
