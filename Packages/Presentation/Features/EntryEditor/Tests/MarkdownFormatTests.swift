import Testing

@testable import EntryEditorFeature

@Suite("MarkdownFormat")
struct MarkdownFormatTests {
    @Test func wrapsAndKeepsTheWordsSelected() {
        let result = MarkdownFormat.bold.apply(to: "fix the leak", selection: 4..<7)
        #expect(result.text == "fix **the** leak")
        #expect(result.selection == 6..<9)
    }

    @Test func unwrapsWhenAlreadyFormatted() {
        let result = MarkdownFormat.bold.apply(to: "fix **the** leak", selection: 6..<9)
        #expect(result.text == "fix the leak")
        #expect(result.selection == 4..<7)
    }

    @Test func italicInsideBoldWrapsInsteadOfBreakingBold() {
        let result = MarkdownFormat.italic.apply(to: "**the**", selection: 2..<5)
        #expect(result.text == "***the***")
    }

    @Test func emptySelectionLeavesTheCursorBetweenMarkers() {
        let result = MarkdownFormat.code.apply(to: "run ", selection: 4..<4)
        #expect(result.text == "run ``")
        #expect(result.selection == 5..<5)
    }

    @Test func linkSelectsTheAddressPlaceholder() {
        let result = MarkdownFormat.link.apply(to: "see docs", selection: 4..<8)
        #expect(result.text == "see [docs](https://)")
        let characters = Array(result.text)
        #expect(String(characters[result.selection]) == "https://")
    }

    @Test func outOfRangeSelectionIsClamped() {
        let result = MarkdownFormat.italic.apply(to: "ab", selection: 5..<9)
        #expect(result.text == "ab**")
    }
}
