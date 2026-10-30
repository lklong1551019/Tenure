import DesignSystem
import Domain
import SwiftUI

/// One task in the grid: kind, date, name, the first line of its story, and the first metric.
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
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.mutedInk)
            }
            Text(entry.name.isEmpty ? "Untitled" : entry.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let excerpt = entry.excerpt {
                Text(excerpt)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.secondaryInk)
                    .lineLimit(2)
                    .lineSpacing(2)
            } else {
                Text("No write-up yet.")
                    .font(.system(size: 13))
                    .italic()
                    .foregroundStyle(Palette.mutedInk)
            }
            Spacer(minLength: 0)
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
                .font(.system(size: 12))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Metrics.controlRadius))
            }
            if boardName != nil || entry.link?.isEmpty == false || !entry.tags.isEmpty {
                HStack(spacing: 8) {
                    if let boardName {
                        Label(boardName, systemImage: "building.2")
                    }
                    if entry.link?.isEmpty == false {
                        Image(systemName: "link").accessibilityLabel("Has link")
                    }
                    ForEach(entry.tags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Palette.mutedInk)
                .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cornerRadius)
                .strokeBorder(isSelected ? Palette.accent : Palette.border, lineWidth: isSelected ? 2 : 1)
        )
        .cardShadow()
        .contentShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The detail pane: the whole story of one task.
struct EntryDetailView: View {
    let entry: Entry
    let boardName: String
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onOpenLink: () -> Void
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
                    ForEach(entry.sections, id: \.title) { section in
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
            Text(entry.name.isEmpty ? "Untitled" : entry.name)
                .font(.system(size: 24, weight: .bold))
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
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.mutedInk)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    private func sectionView(_ section: StorySection) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: section.symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(section.tint.foreground)
                .frame(width: 28, height: 28)
                .background(section.tint.background, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Palette.mutedInk)
                Text(markdown(section.text))
                    .font(.system(size: 14))
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
                .font(.system(size: 11, weight: .semibold))
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
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text("Add the problem, why it mattered, the solution, the impact, and the numbers that prove it.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            Button("Write the story", action: onEdit)
                .buttonStyle(SecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Metrics.cornerRadius))
    }

    private func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
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
            .font(.system(size: 12))
            .lineLimit(1)
            .truncationMode(.middle)
            .foregroundStyle(tint?.foreground ?? Palette.secondaryInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint?.background ?? Palette.sunken, in: RoundedRectangle(cornerRadius: 6))
    }
}

/// Lays children out left to right, wrapping to a new line when the row is full.
private struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                let width = min(size.width, bounds.width)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(width: width, height: size.height)
                )
                x += width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let itemWidth = min(size.width, width)
            if !row.indices.isEmpty && row.width + spacing + itemWidth > width {
                rows.append(row)
                row = Row()
            }
            row.width += (row.indices.isEmpty ? 0 : spacing) + itemWidth
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
