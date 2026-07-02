import Testing
@testable import HoldemUI

@Suite("Chip formatter")
struct ChipFormatterTests {
    @Test("chip amounts are grouped and never negative")
    func chipAmountsAreGroupedAndNeverNegative() {
        #expect(ChipFormatter.string(0) == "0")
        #expect(ChipFormatter.string(42) == "42")
        #expect(ChipFormatter.string(1_552) == "1,552")
        #expect(ChipFormatter.string(1_000_000) == "1,000,000")
        #expect(ChipFormatter.string(-12) == "0")
    }
}
