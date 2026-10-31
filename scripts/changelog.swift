// Adds one release to App/Sources/Changelog.json from commit subjects, and prints the same
// notes as text for the release tag. Called by scripts/release.sh.
//
//   git log --format=%s <prev>..HEAD | swift scripts/changelog.swift <version> <code> <date>
//   swift scripts/changelog.swift --print <code>       notes of a release already in the file
//
// Subjects read `feat: add markdown export` or `feat(ui): add markdown export`; the Credentials
// Manager form `[CM-12][Tag] feat: ...` is accepted too. Only user-facing types make it in:
// feat -> New, fix -> Fixed, ui and perf -> Improved. chore, docs, test, build, ci, refactor,
// and revert stay out.
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
let file = URL(fileURLWithPath: "App/Sources/Changelog.json")

/// Tag message body: plain text, no markup.
func notesText(_ sections: [String: [String]]) -> String {
    var notes: [String] = []
    for (key, title) in [("new", "New"), ("fixed", "Fixed"), ("improved", "Improved")] {
        let items = sections[key] ?? []
        guard !items.isEmpty else { continue }
        notes.append(title)
        notes += items.map { "- \($0)" }
        notes.append("")
    }
    return notes.isEmpty ? "Maintenance and internal changes." : notes.joined(separator: "\n")
}

if arguments.count == 2, arguments[0] == "--print" {
    let data = try Data(contentsOf: file)
    let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let releases = root?["releases"] as? [[String: Any]] ?? []
    guard let release = releases.first(where: { $0["code"] as? String == arguments[1] }) else {
        FileHandle.standardError.write(Data("\(arguments[1]) is not in \(file.path)\n".utf8))
        exit(1)
    }
    print(notesText(release.mapValues { $0 as? [String] ?? [] }))
    exit(0)
}

guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: changelog.swift <version> <code> <date> | --print <code>\n".utf8))
    exit(2)
}
let (version, code, date) = (arguments[0], arguments[1], arguments[2])

/// `type: summary` or `type(scope): summary`, optionally after `[CM-12]` or `[CM-12][Tag] `.
let subjectPattern = try NSRegularExpression(
    pattern: #"^(?:\[[A-Z]+-[0-9]+\](?:\[[^\]]+\])? )?(feat|fix|ui|perf)(?:\([^)]*\))?!?: (.+)$"#
)

func entry(from subject: String) -> (section: String, text: String)? {
    let range = NSRange(subject.startIndex..., in: subject)
    guard let match = subjectPattern.firstMatch(in: subject, range: range),
        let typeRange = Range(match.range(at: 1), in: subject),
        let summaryRange = Range(match.range(at: 2), in: subject)
    else { return nil }
    let summary = subject[summaryRange].trimmingCharacters(in: .whitespaces)
    let text = summary.prefix(1).uppercased() + summary.dropFirst()
    switch subject[typeRange] {
    case "feat": return ("new", text)
    case "fix": return ("fixed", text)
    default: return ("improved", text)
    }
}

var sections: [String: [String]] = ["new": [], "fixed": [], "improved": []]
// git log lists newest first; notes read oldest first.
let subjects = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
    .split(separator: "\n").map(String.init).reversed()
for subject in subjects {
    if let (section, text) = entry(from: subject), !(sections[section] ?? []).contains(text) {
        sections[section, default: []].append(text)
    }
}

let data = (try? Data(contentsOf: file)) ?? Data(#"{"releases": []}"#.utf8)
guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    FileHandle.standardError.write(Data("\(file.path) is not a JSON object\n".utf8))
    exit(1)
}
var releases = root["releases"] as? [[String: Any]] ?? []
// A release is one build: the same version can ship again as a later build (26110103).
guard !releases.contains(where: { $0["code"] as? String == code }) else {
    FileHandle.standardError.write(Data("\(code) is already in \(file.path)\n".utf8))
    exit(1)
}
releases.insert(
    [
        "version": version, "code": code, "date": date,
        "new": sections["new"] ?? [], "fixed": sections["fixed"] ?? [], "improved": sections["improved"] ?? [],
    ],
    at: 0
)
root["releases"] = releases
let output = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
try (output + Data("\n".utf8)).write(to: file)

print(notesText(sections))
