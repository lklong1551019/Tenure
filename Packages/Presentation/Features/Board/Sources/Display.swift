import DesignSystem
import Domain
import Foundation

extension EntryType {
    var tint: Tint {
        switch self {
        case .product: .violet
        case .dev: .teal
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

    /// Markdown sections in story order, empty ones left out.
    var sections: [(title: String, text: String)] {
        [
            ("Problem", problem),
            ("Why", why),
            ("Solution", solution),
            ("Impact", impact),
            ("Difficulties and how they were solved", difficulties),
        ]
        .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
