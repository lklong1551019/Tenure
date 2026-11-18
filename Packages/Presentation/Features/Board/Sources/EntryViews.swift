import DesignSystem
import Domain
import SwiftUI

/// One task in the grid: kind, date, name, the start of its story, and the first metric.
/// A task without a story has a dashed border and says so in its last line.
struct EntryCard: View {
    let entry: Entry
    /// Nil when the board is obvious: one board selected, or only one board at all.
    let boardName: String?
    let isSelected: Bool
    /// The year the board is filtered to, if any: a task that began earlier says so.
    var filterYear: Int?
    /// Under a month heading the date drops its year ("12 Mar").
    var underMonthHeading = false

    private var hasStory: Bool { entry.excerpt != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Badge(entry.type.title, tint: entry.type.tint)
                Spacer()
                Text(underMonthHeading ? entry.date.dayMonth : entry.date.short)
                    .appFont(12)
                    .foregroundStyle(Palette.mutedInk)
            }
            Text(entry.displayName)
                .appFont(15, weight: .semibold)
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let excerpt = entry.excerpt {
                Text(excerpt)
                    .appFont(13)
                    .foregroundStyle(Palette.secondaryInk)
                    .lineLimit(2)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
            if let filterYear, entry.date.year < filterYear {
                Badge("Started in \(String(entry.date.year))", tint: .amber)
            }
            if let metric = entry.metrics.first {
                HStack(spacing: 6) {
                    Text(metric.label).foregroundStyle(Palette.secondaryInk)
                    Spacer(minLength: 4)
                    if let before = metric.before, !before.isEmpty {
                        Text(before).foregroundStyle(Palette.mutedInk)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(Palette.mutedInk)
                            .accessibilityLabel("to")
                    }
                    Text(metric.withUnit(metric.after))
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.ink)
                    if let change = metric.changeText {
                        ChangePill(change)
                    }
                }
                .appFont(12)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Metrics.controlRadius))
            }
            footer
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cornerRadius))
        .overlay(border)
        .cardShadow()
        .contentShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The link as a ticket key in the accent color, the tags, the board, and "No story".
    @ViewBuilder
    private var footer: some View {
        let link = entry.link.flatMap { $0.isEmpty ? nil : $0 }
        if link != nil || boardName != nil || !entry.tags.isEmpty || !hasStory {
            HStack(spacing: 8) {
                if let link {
                    Label(LinkLabel.text(link), systemImage: "link")
                        .foregroundStyle(Palette.accentInk)
                        .help(link)
                        .layoutPriority(1)
                }
                if let boardName {
                    Label(boardName, systemImage: "building.2")
                }
                ForEach(entry.tags.prefix(3), id: \.self) { tag in
                    Text("#\(tag)")
                }
                Spacer(minLength: 0)
                if !hasStory {
                    Text("No story").fixedSize()
                }
            }
            .appFont(12)
            .foregroundStyle(Palette.mutedInk)
            .lineLimit(1)
        }
    }

    private var border: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerRadius)
        return Group {
            if isSelected {
                shape.strokeBorder(Palette.accent, lineWidth: 2)
            } else if hasStory {
                shape.strokeBorder(Palette.border, lineWidth: 1)
            } else {
                shape.strokeBorder(Palette.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
    }
}

/// The detail pane: the whole story of one task.
struct EntryDetailView: View {
    let entry: Entry
    let boardName: String
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onOpenLink: () -> Void
    /// A link clicked inside the story; goes through the same check as the task's link.
    let onOpenURL: (URL) -> Void
    let onCopy: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                Divider()
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(entry.sections, id: \.part) { section in
                        sectionView(section)
                        Divider()
                    }
                    if !entry.metrics.isEmpty {
                        metrics
                            .padding(.top, 20)
                    }
                    if entry.sections.isEmpty && entry.metrics.isEmpty {
                        emptyStory
                            .padding(.top, 20)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
            // Without this the column shrinks to its content when the story is short.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .environment(
            \.openURL,
            OpenURLAction { url in
                onOpenURL(url)
                return .handled
            }
        )
        .background(Palette.surface)
        .toolbar {
            ToolbarItemGroup {
                Button("Copy as Markdown", systemImage: "doc.on.doc", action: onCopy)
                    .help("Copy as Markdown (Shift-Cmd-C)")
                Button("Edit", systemImage: "pencil", action: onEdit)
                    .help("Edit task")
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                    .help("Delete task")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Badge(entry.type.title, tint: entry.type.tint)
            Text(entry.displayName)
                .appFont(24, weight: .bold)
                .foregroundStyle(Palette.ink)
                .textSelection(.enabled)
            FlowRow {
                MetaChip(entry.period, systemImage: "calendar")
                MetaChip(boardName, systemImage: "building.2")
                if let link = entry.link, !link.isEmpty {
                    Button(action: onOpenLink) {
                        MetaChip(link, systemImage: "link", tint: .teal)
                    }
                    .buttonStyle(.plain)
                    .help(link)
                }
                ForEach(entry.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .appFont(12)
                        .foregroundStyle(Palette.mutedInk)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    private func sectionView(_ section: StorySection) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: section.symbol)
                .appFont(12, weight: .bold)
                .foregroundStyle(section.tint.foreground)
                .frame(width: 28, height: 28)
                .background(section.tint.background, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title.uppercased())
                    .appFont(11, weight: .semibold)
                    .tracking(0.6)
                    .foregroundStyle(Palette.mutedInk)
                Text(StoryText.attributed(section.text))
                    .appFont(14)
                    .lineSpacing(4)
                    .foregroundStyle(Palette.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 16)
    }

    private var metrics: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("METRICS")
                .appFont(11, weight: .semibold)
                .tracking(0.6)
                .foregroundStyle(Palette.mutedInk)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                ForEach(entry.metrics) { metric in
                    MetricTile(
                        label: metric.label,
                        before: metric.before.map { metric.withUnit($0) },
                        after: metric.withUnit(metric.after),
                        change: metric.changeText,
                        note: metric.note
                    )
                }
            }
        }
    }

    private var emptyStory: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No write-up yet")
                .appFont(15, weight: .semibold)
                .foregroundStyle(Palette.ink)
            Text("Add the problem, why it mattered, the solution, the impact, and the numbers that prove it.")
                .appFont(13)
                .foregroundStyle(Palette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            Button("Write the story", action: onEdit)
                .buttonStyle(SecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Metrics.cornerRadius))
    }
}

/// Icon and text in a small well, for a task's date, board, and link.
private struct MetaChip: View {
    let text: String
    let systemImage: String
    let tint: Tint?

    init(_ text: String, systemImage: String, tint: Tint? = nil) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        Label(text, systemImage: systemImage)
            .appFont(12)
            .lineLimit(1)
            .truncationMode(.middle)
            .foregroundStyle(tint?.foreground ?? Palette.secondaryInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint?.background ?? Palette.sunken, in: RoundedRectangle(cornerRadius: 6))
    }
}

/// "October 2026  6 tasks": the heading over one month's tasks in the grid and the table.
struct MonthHeading: View {
    let month: YearMonth
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(month.long)
                .appFont(13, weight: .semibold)
                .foregroundStyle(Palette.ink)
            Text(count == 1 ? "1 task" : "\(count) tasks")
                .appFont(12)
                .foregroundStyle(Palette.mutedInk)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
