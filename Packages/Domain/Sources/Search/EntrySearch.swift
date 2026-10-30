import Foundation

/// Ranks entries by name, tags, link, and type. The write-up is left out on purpose: a short
/// query would match half the ledger through common words.
public enum EntrySearch {
    public static func search(_ query: String, in entries: [Entry]) -> [Entry] {
        let terms = terms(of: query)
        guard !terms.isEmpty else { return entries }
        let scored: [(entry: Entry, score: Int)] = entries.compactMap { entry in
            score(terms, entry).map { (entry, $0) }
        }
        return
            scored
            .sorted { lhs, rhs in
                lhs.score != rhs.score
                    ? lhs.score > rhs.score
                    : lhs.entry.name.localizedStandardCompare(rhs.entry.name) == .orderedAscending
            }
            .map(\.entry)
    }

    /// Whether every term of `query` matches; an empty query matches everything.
    public static func matches(_ query: String, _ entry: Entry) -> Bool {
        matches(terms: terms(of: query), entry)
    }

    /// `matches(_:_:)` with the query split once, for filtering many entries.
    static func matches(terms: [String], _ entry: Entry) -> Bool {
        terms.isEmpty || score(terms, entry) != nil
    }

    /// Case, diacritic, and width insensitive, so "viet" finds "Việt".
    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func terms(of query: String) -> [String] {
        normalize(query).split(separator: " ").map(String.init)
    }

    private static func score(_ terms: [String], _ entry: Entry) -> Int? {
        let name = normalize(entry.name)
        var total = 0
        for term in terms {
            guard let score = score(term, entry, name: name) else { return nil }
            total += score
        }
        return total
    }

    /// `name` is the entry's name, normalized once for all terms.
    private static func score(_ term: String, _ entry: Entry, name: String) -> Int? {
        if name.hasPrefix(term) { return 100 }
        if name.split(separator: " ").contains(where: { $0.hasPrefix(term) }) { return 80 }
        if name.contains(term) { return 60 }
        if entry.tags.contains(where: { normalize($0).hasPrefix(term) }) { return 40 }
        if normalize(entry.link ?? "").contains(term) { return 30 }
        if normalize(entry.type.rawValue).hasPrefix(term) { return 20 }
        if isSubsequence(term, of: name) { return 10 }
        return nil
    }

    private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var remaining = needle[...]
        for character in haystack where character == remaining.first {
            remaining = remaining.dropFirst()
            if remaining.isEmpty { return true }
        }
        return remaining.isEmpty
    }
}
