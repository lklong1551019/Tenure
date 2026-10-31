import DesignSystem
import Domain
import Foundation

extension EntryType {
    var tint: Tint { .kind(rawValue) }
}

extension YearMonth {
    /// "Jul 2017"
    var short: String {
        date().formatted(.dateTime.month(.abbreviated).year())
    }
}

extension DayDate {
    /// "12 Mar 2026"
    var short: String {
        date().formatted(.dateTime.day().month(.abbreviated).year())
    }
}

extension Board {
    /// "Jul 2017 - Aug 2019", or "Sep 2019 - now", in the Mac's language.
    var period: String { period(\.short) }
}

extension Entry {
    /// "12 Mar 2026", or a span, in the Mac's language.
    var period: String { period(\.short) }

    /// The story parts to show, each with its mark: an SF Symbol and a tint.
    var sections: [StorySection] {
        story.map { StorySection(part: $0.part, text: $0.text) }
    }

    /// First story part as one plain line, for the card.
    var excerpt: String? {
        guard let first = story.first?.text else { return nil }
        let plain = String(StoryText.attributed(first).characters)
        return plain.components(separatedBy: .newlines).joined(separator: " ")
    }
}

struct StorySection {
    let part: StoryPart
    let text: String

    var title: String { part.title }

    var symbol: String {
        switch part {
        case .problem: "exclamationmark"
        case .why: "questionmark"
        case .solution: "checkmark"
        case .impact: "arrow.up.right"
        case .difficulties: "mountain.2"
        }
    }

    var tint: Tint {
        switch part {
        case .problem: .red
        case .why: .amber
        case .solution: .teal
        case .impact: .violet
        case .difficulties: .blue
        }
    }
}

/// Story text as shown: inline Markdown (**bold**, *italic*, `code`, links). The HTML tags
/// people type by habit (<b>, <i>, <code>, <br>) are read as their Markdown twins.
enum StoryText {
    private static let tags: [(pattern: String, markdown: String)] = [
        ("</?(b|strong)>", "**"),
        ("</?(i|em)>", "*"),
        ("</?code>", "`"),
        ("<br\\s*/?>", "\n"),
    ]

    static func markdown(_ text: String) -> String {
        tags.reduce(text) { text, tag in
            text.replacingOccurrences(
                of: tag.pattern,
                with: tag.markdown,
                options: [.regularExpression, .caseInsensitive]
            )
        }
    }

    /// Links keep only http and https; any other scheme (another app's, `file:`) is shown as
    /// plain text, since story text can come from an imported or synced file.
    static func attributed(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        guard var result = try? AttributedString(markdown: markdown(text), options: options) else {
            return AttributedString(text)
        }
        for run in result.runs {
            guard let url = run.link else { continue }
            if !["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                result[run.range].link = nil
            }
        }
        return result
    }
}
