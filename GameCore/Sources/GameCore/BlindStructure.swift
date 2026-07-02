enum BlindStructure {
    static func normalized(smallBlind: Int, bigBlind: Int) -> (smallBlind: Int, bigBlind: Int) {
        let smallBlind = max(1, smallBlind)
        let minimumBigBlind = doubledWithoutOverflow(smallBlind)
        return (smallBlind, max(minimumBigBlind, bigBlind))
    }

    private static func doubledWithoutOverflow(_ value: Int) -> Int {
        let result = value.multipliedReportingOverflow(by: 2)
        return result.overflow ? Int.max : result.partialValue
    }
}
