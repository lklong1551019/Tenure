import Foundation

/// The five parts of a task's story, in the order they are told.
public enum StoryPart: CaseIterable, Sendable {
    case problem
    case why
    case solution
    case impact
    case difficulties

    public var title: String {
        switch self {
        case .problem: "Problem"
        case .why: "Why"
        case .solution: "Solution"
        case .impact: "Impact"
        case .difficulties: "Difficulties and how they were solved"
        }
    }
}

extension Entry {
    /// The story parts in order, empty ones left out.
    public var story: [(part: StoryPart, text: String)] {
        StoryPart.allCases
            .map { ($0, text(of: $0)) }
            .filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    public func text(of part: StoryPart) -> String {
        switch part {
        case .problem: problem
        case .why: why
        case .solution: solution
        case .impact: impact
        case .difficulties: difficulties
        }
    }

    /// The name, or "Untitled" when it is empty.
    public var displayName: String {
        name.isEmpty ? "Untitled" : name
    }

    /// "12 Mar 2026", or "12 Mar 2026 - 20 Mar 2026" for a span; `format` writes one day.
    public func period(_ format: (DayDate) -> String) -> String {
        guard let endDate, endDate != date else { return format(date) }
        return "\(format(date)) - \(format(endDate))"
    }

    /// Whether any day from its date to its end date falls in `year`.
    func touches(_ year: Int) -> Bool {
        let end = max(date.year, endDate?.year ?? date.year)
        return (date.year...end).contains(year)
    }
}

extension Board {
    /// "Jul 2017 - Aug 2019", or "Sep 2019 - now"; `format` writes one month.
    public func period(_ format: (YearMonth) -> String) -> String {
        "\(format(start)) - \(end.map(format) ?? "now")"
    }
}

extension Int {
    /// "1 task", "3 tasks": the count with `noun`, plural unless it is one.
    public func counted(_ noun: String) -> String {
        self == 1 ? "1 \(noun)" : "\(self) \(noun)s"
    }
}

extension Metric {
    /// Change from before to after, as a fraction: -0.44 for 18 to 10. Nil unless both are
    /// plain numbers and before is not zero.
    public var change: Double? {
        guard let before = before.flatMap(Self.number), let after = Self.number(after), before != 0 else {
            return nil
        }
        return (after - before) / abs(before)
    }

    /// "-44%", "+12%", "+0.5%".
    public var changeText: String? {
        guard let change else { return nil }
        let percent = change * 100
        let rounded = abs(percent) >= 10 ? percent.rounded() : (percent * 10).rounded() / 10
        let digits = rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
        return (rounded > 0 ? "+" : "") + digits + "%"
    }

    /// "18 ms"; the value alone when there is no unit.
    public func withUnit(_ value: String) -> String {
        guard let unit, !unit.trimmingCharacters(in: .whitespaces).isEmpty else { return value }
        return "\(value) \(unit)"
    }

    /// "1,200" and " 18 " read as numbers; "18ms" does not.
    private static func number(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces))
    }
}
