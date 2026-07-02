import Testing
@testable import GameCore

@Suite("Chip text")
struct ChipTextTests {
    @Test("chip text formats visible chip amounts")
    func formatsVisibleChipAmounts() {
        #expect(ChipText.string(-1) == "0")
        #expect(ChipText.string(999) == "999")
        #expect(ChipText.string(1_000) == "1,000")
        #expect(ChipText.string(1_234_567) == "1,234,567")
    }
}
