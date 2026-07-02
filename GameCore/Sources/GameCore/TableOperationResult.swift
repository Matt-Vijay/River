public enum TableOperationRejection: Sendable, Equatable {
    case duplicateOperation
    case invalidOperationIdentity
    case stale(expected: TableRevision)
    case wrongTable
    case wrongPhase
    case notSeated
    case notActorTurn
    case illegalAction
    case tableFull
    case gameOver
}

public enum TableOperationResult: Sendable, Equatable {
    case applied(TableMessage)
    case unchanged(TableMessage)
    case rejected(TableOperationRejection)
}
