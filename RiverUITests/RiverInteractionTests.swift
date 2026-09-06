import XCTest

@MainActor
final class RiverInteractionTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = ["-riverResetProfile"]
        app.launch()
    }

    func testLobbyToRaiseAndAllInActionFlow() {
        defer { XCUIDevice.shared.orientation = .portrait }
        saveProfile(named: "Maverick")
        XCTAssertFalse(button("lobby.startGame").isEnabled)
        button("lobby.addPlayer").tap()
        button("lobby.addPlayer").tap()
        XCTAssertTrue(button("lobby.startGame").isEnabled)
        button("lobby.startGame").tap()

        revealCurrentHand(for: "Maverick")
        button("table.leave").tap()
        XCTAssertTrue(app.staticTexts[
            "Your current hand will be folded. You will sit out future hands."
        ].exists)
        button("table.leave.cancel").tap()

        let heroFrame = element("table.heroSeat").frame
        button("table.action.raise.expand").tap()
        let slider = app.sliders["table.raise.slider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 2))
        XCTAssertEqual(element("table.heroSeat").frame.minY, heroFrame.minY, accuracy: 1,
                       "Opening raise options must not shift the hero hand")
        slider.adjust(toNormalizedSliderPosition: 0.85)
        XCTAssertNotEqual(button("table.raise.submit").label, "Raise to 20")
        button("table.raise.preset.pot").tap()
        XCTAssertEqual(button("table.raise.submit").label, "Raise to 35")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(button("table.raise.submit").label, "Raise to 35")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(button("table.raise.submit").label, "Raise to 35")
        button("table.raise.close").tap()
        button("table.action.raise.expand").tap()
        button("table.raise.preset.allIn").tap()
        XCTAssertEqual(button("table.raise.submit").label, "Raise to 1,000")
        button("table.raise.submit").tap()

        revealCurrentHand(for: "Guest 1")
        XCTAssertTrue(button("table.action.call").label.contains("995"))
        button("table.action.call").tap()
        revealCurrentHand(for: "Guest 2")
        button("table.action.fold").tap()
        XCTAssertTrue(element("table.result").label.contains("won"))

        button("table.action.dealNext").tap()
        button("table.handoff.reveal").tap()
        XCTAssertTrue(element("table.holeCards").exists)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(element("table.handoff").exists)
        XCTAssertFalse(app.descendants(matching: .any)["table.holeCards"].exists)
        button("table.handoff.reveal").tap()

        let resolve = app.buttons["table.timeout.resolve"]
        XCTAssertTrue(resolve.waitForExistence(timeout: 35))
        XCTAssertFalse(app.buttons["table.action.fold"].exists)
        resolve.tap()
        XCTAssertTrue(resolve.waitForNonExistence(timeout: 3))
    }

    func testProfileSaveGateAndLocalPersistence() {
        let field = app.textFields["profile.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertFalse(button("profile.save").isEnabled)
        let cappedName = "ABCDEFGHIJKLMNOPQRSTUVWX"
        field.tap()
        field.typeText(cappedName + "YZZZ")
        let bounded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", cappedName), object: field)
        XCTAssertEqual(XCTWaiter.wait(for: [bounded], timeout: 2), .completed)
        button("profile.avatar.9").tap()
        XCTAssertTrue(button("profile.avatar.9").label.contains("Selected character"))
        XCTAssertTrue(button("profile.save").isEnabled)
        button("profile.save").tap()
        XCTAssertTrue(element("lobby.localSeat").label.contains(cappedName))

        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(element("lobby.localSeat").label.contains(cappedName))
        XCTAssertFalse(app.textFields["profile.name"].exists)
    }

    private func saveProfile(named name: String) {
        let field = app.textFields["profile.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        XCTAssertTrue(button("profile.save").isEnabled)
        button("profile.save").tap()
        XCTAssertTrue(element("lobby.localSeat").label.contains(name))
    }

    private func button(_ id: String) -> XCUIElement {
        let button = app.buttons.matching(identifier: id).firstMatch
        XCTAssertTrue(button.exists || button.waitForExistence(timeout: 3), "Missing button \(id)")
        return button
    }

    private func element(_ id: String) -> XCUIElement {
        let element = app.descendants(matching: .any)[id]
        XCTAssertTrue(element.exists || element.waitForExistence(timeout: 3), "Missing element \(id)")
        return element
    }

    private func revealCurrentHand(for player: String) {
        XCTAssertTrue(element("table.handoff").label.contains(player))
        XCTAssertFalse(app.descendants(matching: .any)["table.holeCards"].exists,
                       "Hole cards must remain absent until the current player reveals")
        XCTAssertTrue(button("table.leave").exists)
        button("table.handoff.reveal").tap()
        XCTAssertTrue(element("table.holeCards").exists)
        XCTAssertTrue(element("table.heroSeat").label.contains(player))
    }
}
