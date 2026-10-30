import DesignSystem
import Domain
import Foundation

extension EntryType {
    var tint: Tint {
        switch self {
        case .product: .violet
        case .dev: .blue
        case .bugFix: .red
        case .findings: .amber
        default: .neutral
        }
    }
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
    /// "Jul 2017 - Aug 2019", or "Sep 2019 - now".
    var period: String {
        "\(start.short) - \(end?.short ?? "now")"
    }
}

extension Entry {
    var period: String {
        guard let endDate, endDate != date else { return date.short }
        return "\(date.short) - \(endDate.short)"
    }

    /// The story parts to show, each with its mark: an SF Symbol and a tint.
    var sections: [StorySection] {
        story.map { StorySection(title: $0.title, text: $0.text) }
    }

    /// First story part as one plain line, for the card.
    var excerpt: String? {
        guard let first = story.first?.text else { return nil }
        let plain = (try? AttributedString(markdown: first)).map { String($0.characters) } ?? first
        return plain.components(separatedBy: .newlines).joined(separator: " ")
    }
}

struct StorySection {
    let title: String
    let text: String

    var symbol: String {
        switch title {
        case "Problem": "exclamationmark"
        case "Why": "questionmark"
        case "Solution": "checkmark"
        case "Impact": "arrow.up.right"
        default: "mountain.2"
        }
    }

    var tint: Tint {
        switch title {
        case "Problem": .red
        case "Why": .amber
        case "Solution": .teal
        case "Impact": .violet
        default: .blue
        }
    }
}
