// Renders site/releases.html, the release history page on GitHub Pages, from
// App/Sources/Changelog.json (newest release first). Called by scripts/release.sh; run it from
// the repository root after editing the changelog by hand.
//
//   swift scripts/render-releases.swift
//
// Each release shows its version, date, and the New, Fixed, and Improved lists that are not
// empty; the newest carries a "Latest" pill. Every value from the changelog is HTML-escaped.
import Foundation

let changelog = URL(fileURLWithPath: "App/Sources/Changelog.json")
let page = URL(fileURLWithPath: "site/releases.html")

func escape(_ text: String) -> String {
    var escaped = ""
    for character in text {
        switch character {
        case "&": escaped += "&amp;"
        case "<": escaped += "&lt;"
        case ">": escaped += "&gt;"
        case "\"": escaped += "&quot;"
        case "'": escaped += "&#39;"
        default: escaped.append(character)
        }
    }
    return escaped
}

/// `2026-10-30` -> `30 October 2026`, the style of the privacy page; anything else as written.
func displayDate(_ iso: String) -> String {
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.timeZone = TimeZone(identifier: "UTC")
    parser.dateFormat = "yyyy-MM-dd"
    guard let date = parser.date(from: iso) else { return iso }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "d MMMM yyyy"
    return formatter.string(from: date)
}

func section(_ release: [String: Any]) -> String {
    let version = escape(release["version"] as? String ?? "")
    let date = release["date"] as? String ?? ""
    var lines = ["<section>"]
    var heading = "<h2 id=\"v\(version)\">\(version)"
    if release["isLatest"] as? Bool == true {
        heading += " <span class=\"latest\">Latest</span>"
    }
    lines.append(heading + "</h2>")
    if !date.isEmpty {
        lines.append("<p class=\"date\"><time datetime=\"\(escape(date))\">\(escape(displayDate(date)))</time></p>")
    }
    var listed = false
    for (key, title) in [("new", "New"), ("fixed", "Fixed"), ("improved", "Improved")] {
        let items = (release[key] as? [String] ?? []).filter { !$0.isEmpty }
        guard !items.isEmpty else { continue }
        listed = true
        lines.append("<h3>\(title)</h3>")
        lines.append("<ul>")
        lines += items.map { "  <li>\(escape($0))</li>" }
        lines.append("</ul>")
    }
    if !listed {
        lines.append("<p>Maintenance and internal changes.</p>")
    }
    lines.append("</section>")
    return lines.joined(separator: "\n")
}

let data: Data
do {
    data = try Data(contentsOf: changelog)
} catch {
    FileHandle.standardError.write(Data("cannot read \(changelog.path): \(error.localizedDescription)\n".utf8))
    exit(1)
}
guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
    let releases = root["releases"] as? [[String: Any]]
else {
    FileHandle.standardError.write(Data("\(changelog.path) has no \"releases\" list\n".utf8))
    exit(1)
}

var body: String
if releases.isEmpty {
    body = "<p class=\"empty\">No releases yet.</p>"
} else {
    body = releases.enumerated()
        .map { index, release in
            var release = release
            release["isLatest"] = index == 0
            return section(release)
        }
        .joined(separator: "\n\n")
}

let html = """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Tenure - Releases</title>
    <style>
      :root { color-scheme: light dark; }
      body { font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif;
             max-width: 720px; margin: 0 auto; padding: 32px 16px 64px; }
      nav { display: flex; gap: 16px; font-size: 15px; }
      h1 { font-size: 28px; }
      h2 { font-size: 21px; margin: 40px 0 0; }
      h3 { font-size: 16px; margin: 16px 0 4px; }
      ul { margin: 0; padding-left: 24px; }
      .date { opacity: 0.7; margin: 0; }
      .empty { opacity: 0.7; }
      .latest { display: inline-block; vertical-align: middle; margin-left: 8px; padding: 1px 10px;
                border-radius: 999px; font-size: 12px; font-weight: 600; line-height: 1.6;
                color: light-dark(#0a5c2b, #8be0a8); background: light-dark(#d9f2e2, #1d4a2e); }
    </style>
    </head>
    <body>
    <nav><a href="./">Tenure</a> <a href="app/">Web app</a> <a href="releases.html">Releases</a> <a href="privacy.html">Privacy</a></nav>
    <h1>Releases</h1>
    \(body)
    </body>
    </html>

    """

do {
    try FileManager.default.createDirectory(at: page.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(html.utf8).write(to: page)
} catch {
    FileHandle.standardError.write(Data("cannot write \(page.path): \(error.localizedDescription)\n".utf8))
    exit(1)
}
let newest = (releases.first?["version"] as? String).map { ", newest \($0)" } ?? ""
print("rendered site/releases.html: \(releases.count) release(s)\(newest)")
