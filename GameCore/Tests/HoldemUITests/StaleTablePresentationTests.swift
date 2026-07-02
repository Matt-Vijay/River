import Testing
import GameCore
import HoldemUI

@Suite("Stale table presentation")
struct StaleTablePresentationTests {
    @Test("rejected actions explain that the action was not sent")
    func rejectedActionsExplainThatActionWasNotSent() {
        let presentation = StaleTablePresentation(
            summary: "Turn - Pot 120 - Alice to act",
            context: .rejectedAction()
        )

        #expect(presentation.title == "Action not sent")
        #expect(presentation.message == "Turn - Pot 120 - Alice to act")
        #expect(presentation.guidance == "Open the newest River bubble in this chat, then try again.")
    }

    @Test("rejected actions explain why the action was not sent")
    func rejectedActionsExplainWhyActionWasNotSent() {
        let presentation = StaleTablePresentation(
            summary: "Turn - Pot 120 - Alice to act",
            context: .rejectedAction(.notActorTurn)
        )

        #expect(presentation.title == "Action not sent")
        #expect(presentation.message == "Turn - Pot 120 - Alice to act")
        #expect(presentation.guidance == "It is not your turn.")
    }

    @Test("duplicate actions explain how to recover")
    func duplicateActionsExplainHowToRecover() {
        let presentation = StaleTablePresentation(
            summary: "Turn - Pot 120 - Alice to act",
            context: .rejectedAction(.duplicateOperation)
        )

        #expect(presentation.title == "Action not sent")
        #expect(presentation.message == "Turn - Pot 120 - Alice to act")
        #expect(presentation.guidance == "That action was already applied. Open the newest River bubble to keep playing.")
    }

    @Test("wrong table actions explain how to recover")
    func wrongTableActionsExplainHowToRecover() {
        let presentation = StaleTablePresentation(
            summary: "Turn - Pot 120 - Alice to act",
            context: .rejectedAction(.wrongTable)
        )

        #expect(presentation.title == "Action not sent")
        #expect(presentation.message == "Turn - Pot 120 - Alice to act")
        #expect(presentation.guidance == "That action belongs to another table. Open the matching River bubble to keep playing.")
    }

    @Test("wrong phase actions explain how to recover")
    func wrongPhaseActionsExplainHowToRecover() {
        let presentation = StaleTablePresentation(
            summary: "Turn - Pot 120 - Alice to act",
            context: .rejectedAction(.wrongPhase)
        )

        #expect(presentation.title == "Action not sent")
        #expect(presentation.message == "Turn - Pot 120 - Alice to act")
        #expect(presentation.guidance == "That action does not match the current table state. Open the newest River bubble and try again.")
    }

    @Test("encoding failures explain that the table was not sent")
    func encodingFailuresExplainThatTableWasNotSent() {
        let presentation = StaleTablePresentation(
            summary: "Turn - Pot 120 - Alice to act",
            context: .encodingFailed
        )

        #expect(presentation.title == "Could not send table")
        #expect(presentation.message == "Turn - Pot 120 - Alice to act")
        #expect(presentation.guidance == "The table state is too large or invalid. Open the newest River bubble and try again.")
    }

    @Test("invalid payloads explain that the selected bubble cannot be opened")
    func invalidPayloadsExplainSelectedBubbleCannotBeOpened() {
        let presentation = StaleTablePresentation(
            summary: "Invalid table message",
            context: .invalidPayload
        )

        #expect(presentation.title == "Could not open table")
        #expect(presentation.message == "Invalid table message")
        #expect(presentation.guidance == "This River bubble contains an invalid table payload. Open the newest bubble in this chat to keep playing.")
    }
}
