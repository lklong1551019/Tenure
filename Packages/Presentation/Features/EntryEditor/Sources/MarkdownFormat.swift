import Foundation

/// Inline Markdown the editor's format buttons insert around the selected text.
enum MarkdownFormat: CaseIterable, Sendable {
    case bold
    case italic
    case code
    case link

    var title: String {
        switch self {
        case .bold: "Bold"
        case .italic: "Italic"
        case .code: "Code"
        case .link: "Link"
        }
    }

    var symbol: String {
        switch self {
        case .bold: "bold"
        case .italic: "italic"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .link: "link"
        }
    }

    /// Cmd plus this key, while the field has focus. Link takes L: Cmd-K is quick search.
    var key: Character {
        switch self {
        case .bold: "b"
        case .italic: "i"
        case .code: "e"
        case .link: "l"
        }
    }

    private var markers: (open: String, close: String) {
        switch self {
        case .bold: ("**", "**")
        case .italic: ("*", "*")
        case .code: ("`", "`")
        case .link: ("[", "](https://)")
        }
    }

    /// Wraps `selection` (character offsets into `text`) in this format's markers, or unwraps
    /// it when the markers are already right around it. Returns the new text and what to
    /// select next: the same words, or for a new link its address placeholder.
    func apply(to text: String, selection: Range<Int>) -> (text: String, selection: Range<Int>) {
        let characters = Array(text)
        let lower = min(max(selection.lowerBound, 0), characters.count)
        let upper = min(max(selection.upperBound, lower), characters.count)
        let (open, close) = (Array(markers.open), Array(markers.close))
        let selected = Array(characters[lower..<upper])

        let before = characters[..<lower]
        let after = characters[upper...]
        if before.suffix(open.count).elementsEqual(open), after.prefix(close.count).elementsEqual(close),
            !isBoldInsideItalic(before: before, after: after)
        {
            let unwrapped = Array(before.dropLast(open.count)) + selected + Array(after.dropFirst(close.count))
            let start = lower - open.count
            return (String(unwrapped), start..<(start + selected.count))
        }

        let wrapped = Array(before) + open + selected + close + Array(after)
        let start = lower + open.count
        if self == .link {
            // Select "https://" so typing the address replaces it.
            let address = start + selected.count + 2
            return (String(wrapped), address..<(address + 8))
        }
        return (String(wrapped), start..<(start + selected.count))
    }

    /// Italic's single star must not unwrap one side of a bold pair: in `**word**`, the star
    /// next to `word` belongs to bold.
    private func isBoldInsideItalic(before: ArraySlice<Character>, after: ArraySlice<Character>) -> Bool {
        self == .italic && before.suffix(2).elementsEqual(["*", "*"]) && after.prefix(2).elementsEqual(["*", "*"])
    }
}
