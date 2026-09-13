import XCTest

@MainActor
final class RiverInteractionTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testProfileAndTable() {
        let app = XCUIApplication()
        app.launchArguments = ["-riverResetProfile"]
        app.launch()
        let name = app.textFields["profile.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["profile.save"].isEnabled)
        name.tap()
        name.typeText("Morgan")
        app.buttons["profile.save"].tap()
        XCTAssertFalse(app.buttons["lobby.startGame"].isEnabled)
        app.buttons["lobby.addPlayer"].coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["lobby.startGame"].isEnabled)
        app.buttons["lobby.startGame"].tap()
        XCTAssertTrue(app.buttons["table.handoff.reveal"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["table.holeCards"].exists)
        app.buttons["table.handoff.reveal"].tap()
        XCTAssertTrue(app.buttons["table.raise"].waitForExistence(timeout: 3))
        capture(app, "Live hand")
        app.buttons["table.raise"].tap()
        XCTAssertTrue(app.buttons["raise.cancel"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.sliders["raise.slider"].value as? String, "20 chips")
        XCTAssertEqual(app.buttons["raise.submit"].label, "Raise to 20 chips")
        capture(app, "Raise sheet")
        app.buttons["raise.cancel"].tap()
        app.buttons["table.raise"].tap()
        app.buttons["raise.allIn"].tap()
        XCTAssertEqual(app.sliders["raise.slider"].value as? String, "1,000 chips")
        XCTAssertEqual(app.buttons["raise.submit"].label, "Raise to 1,000 chips")
        app.buttons["raise.submit"].tap()
        XCTAssertTrue(app.buttons["table.handoff.reveal"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["table.call"].exists)
        app.buttons["table.handoff.reveal"].tap()
        XCTAssertFalse(app.buttons["table.raise"].exists)
        app.buttons["table.call"].tap()
        XCTAssertTrue(app.staticTexts["table.result"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["table.board"].exists)
        capture(app, "Showdown")
        if app.buttons["table.new"].exists {
            XCTAssertFalse(app.buttons["table.leave"].exists)
            XCTAssertFalse(app.staticTexts["All in"].exists)
            app.buttons["table.new"].tap()
            XCTAssertTrue(app.buttons["lobby.addPlayer"].waitForExistence(timeout: 2))
        }
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["lobby.startGame"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.textFields["profile.name"].exists)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSixSeatsRotationAndPrivacy() {
        let app = XCUIApplication()
        app.launch()
        if app.textFields["profile.name"].exists {
            app.textFields["profile.name"].tap()
            app.textFields["profile.name"].typeText("Morgan")
            app.buttons["profile.save"].tap()
        }
        for _ in 0..<5 { app.buttons["lobby.addPlayer"].tap() }
        XCTAssertFalse(app.buttons["lobby.addPlayer"].exists)
        app.buttons["lobby.startGame"].tap()
        XCTAssertTrue(app.buttons["table.handoff.reveal"].waitForExistence(timeout: 3))
        let board = app.descendants(matching: .any)["table.board"].firstMatch
        let boardFrame = board.frame
        let nameFrame = app.staticTexts["table.hero.name"].frame
        app.buttons["table.handoff.reveal"].tap()
        XCTAssertEqual(board.frame, boardFrame)
        XCTAssertEqual(app.staticTexts["table.hero.name"].frame, nameFrame)
        let hero = app.descendants(matching: .any)["table.hero"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 2))
        XCTAssertLessThan(app.buttons["table.call"].frame.maxY, hero.frame.minY)
        capture(app, "Six seats portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 3), .completed)
        capture(app, "Six seats landscape")
        XCUIDevice.shared.orientation = .portrait
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["table.handoff.reveal"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["table.holeCards"].exists)
        app.buttons["table.handoff.reveal"].tap()
        app.buttons["table.call"].tap()
        XCTAssertTrue(app.buttons["table.handoff.reveal"].waitForExistence(timeout: 3))
        XCTAssertEqual(board.frame.minY, boardFrame.minY, accuracy: 0.5)
        XCTAssertFalse(app.descendants(matching: .any)["table.holeCards"].exists)
    }
}

@MainActor
final class RiverMessagesTests: XCTestCase {
    func testInvitationReopensAndCanLeaveAndRejoin() {
        continueAfterFailure = false
        // Install this build's embedded extension before Messages opens it.
        let river = XCUIApplication()
        river.launch()
        river.terminate()
        let app = XCUIApplication(bundleIdentifier: "com.apple.MobileSMS")
        app.launch()
        let recipient = NSPredicate(format: "label BEGINSWITH %@", "+1 (888) 555-1212")
        if !app.buttons.matching(identifier: "ConversationTitle").matching(recipient).firstMatch.exists {
            let conversation = app.cells.containing(recipient).firstMatch
            XCTAssertTrue(conversation.waitForExistence(timeout: 5))
            conversation.tap()
        }
        XCTAssertTrue(app.buttons["add"].waitForExistence(timeout: 3))
        app.buttons["add"].tap()
        for _ in 0..<4 {
            let river = app.popovers.staticTexts["River"]
            if river.exists && river.isHittable { river.tap(); break }
            app.popovers.firstMatch.swipeUp()
        }
        let profile = app.textFields["profile.name"]
        if profile.waitForExistence(timeout: 1) {
            profile.tap()
            profile.typeText("Morgan")
            app.buttons["profile.save"].tap()
        }
        let send = app.buttons["conversation.sendTable"]
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        send.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(send.waitForNonExistence(timeout: 5))
        sendDraft(app)
        let bubbles = app.collectionViews["TranscriptCollectionView"].links.matching(NSPredicate(format: "label CONTAINS %@", "Open table"))
        XCTAssertTrue(bubbles.firstMatch.waitForExistence(timeout: 5))
        bubbles.allElementsBoundByIndex.last!.tap()
        let start = app.buttons["lobby.startGame"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertFalse(start.isEnabled)
        XCTAssertFalse(app.buttons["lobby.addPlayer"].exists)
        let leave = app.buttons["table.leave"]
        XCTAssertTrue(leave.exists)
        leave.tap()
        tapAlert("table.leave.cancel", in: app)
        XCTAssertTrue(leave.waitForExistence(timeout: 2))
        leave.tap()
        tapAlert("table.leave.confirm", in: app)
        XCTAssertTrue(start.waitForNonExistence(timeout: 5))
        sendDraft(app)
        XCTAssertTrue(bubbles.firstMatch.waitForExistence(timeout: 5))
        bubbles.allElementsBoundByIndex.last!.tap()
        XCTAssertTrue(leave.waitForExistence(timeout: 5))
        XCTAssertFalse(start.isEnabled)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Messages reopened and rejoined"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func sendDraft(_ app: XCUIApplication) {
        let draft = app.buttons["Remove app from message"]
        if draft.waitForExistence(timeout: 2) {
            let send = app.otherElements["MessageEntryView"].buttons["sendButton"]
            XCTAssertTrue(send.isEnabled)
            send.tap()
        }
    }

    private func tapAlert(_ id: String, in app: XCUIApplication) {
        let button = app.buttons.matching(identifier: id).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 2))
        // Messages duplicates the remote alert's AX buttons; tap its actual frame.
        let frame = button.frame
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
    }
}
