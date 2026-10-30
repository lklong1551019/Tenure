import DesignSystem
import Domain
import SwiftUI

/// One task in the grid: kind, date, name, and the first metric as a teaser.
struct EntryCard: View {
    let entry: Entry
    let boardName: String?
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Badge(entry.type.title, tint: entry.type.tint)
                Spacer()
                Text(entry.date.short)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.mutedInk)
            }
            Text(entry.name.isEmpty ? "Untitled" : entry.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let metric = entry.metrics.first {
                HStack(spacing: 4) {
                    Text(metric.label).foregroundStyle(Palette.secondaryInk)
                    if let before = metric.before, !before.isEmpty {
                        Text(before).foregroundStyle(Palette.mutedInk)
                        Image(systemName: "arrow.right").foregroundStyle(Palette.mutedInk)
                    }
                    Text(metric.after).foregroundStyle(Palette.success)
                }
                .font(.system(size: 11))
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                if let boardName {
                    Text(boardName)
                }
                if entry.link?.isEmpty == false {
                    Image(systemName: "link").accessibilityLabel("Has link")
                }
                ForEach(entry.tags.prefix(2), id: \.self) { tag in
                    Text("#\(tag)")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(Palette.mutedInk)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cornerRadius)
                .strokeBorder(isSelected ? Palette.accent : Palette.border, lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The inspector: the whole story of one task.
struct EntryDetailView: View {
    let entry: Entry
    let boardName: String
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onOpenLink: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                ForEach(entry.sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.mutedInk)
                        Text(markdown(section.text))
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.ink)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if !entry.metrics.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Metrics")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.mutedInk)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                            ForEach(entry.metrics) { metric in
                                MetricTile(
                                    label: metric.label,
                                    before: metric.before.map { withUnit($0, metric.unit) },
                                    after: withUnit(metric.after, metric.unit),
                                    note: metric.note
                                )
                            }
                        }
                    }
                }
                if entry.sections.isEmpty && entry.metrics.isEmpty {
                    Text("No write-up yet. Edit the task to add the problem, the solution, and the numbers.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.secondaryInk)
                }
            }
            .padding(20)
        }
        .background(Palette.ground)
        .toolbar {
            ToolbarItemGroup {
                Button("Edit", systemImage: "pencil", action: onEdit)
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Badge(entry.type.title, tint: entry.type.tint)
            Text(entry.name.isEmpty ? "Untitled" : entry.name)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .textSelection(.enabled)
            HStack(spacing: 12) {
                Label(entry.period, systemImage: "calendar")
                Label(boardName, systemImage: "building.2")
            }
            .font(.system(size: 12))
            .foregroundStyle(Palette.secondaryInk)
            if let link = entry.link, !link.isEmpty {
                Button(action: onOpenLink) {
                    Label(link, systemImage: "link")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
                .help(link)
            }
            if !entry.tags.isEmpty {
                Text(entry.tags.map { "#\($0)" }.joined(separator: "  "))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.mutedInk)
            }
        }
    }

    private func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    private func withUnit(_ value: String, _ unit: String?) -> String {
        guard let unit, !unit.isEmpty else { return value }
        return "\(value) \(unit)"
    }
}
