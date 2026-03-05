import SwiftUI

struct CommitHistoryView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var hoveredCommit: String?
    @State private var showCommitActions = false

    private let graphColWidth: CGFloat = 14
    private let rowHeight: CGFloat = 48

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#0D1117").ignoresSafeArea()

            if vm.commits.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No commits yet")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text("Make your first commit in the Changes tab")
                        .font(.caption)
                        .foregroundColor(Color.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Top padding so ref badges on the first commit don't crowd the tab bar
                        Color.clear.frame(height: 6)
                        ForEach(vm.commits) { commit in
                            CommitRow(
                                commit: commit,
                                isSelected: vm.selectedCommit?.id == commit.id,
                                isHovered: hoveredCommit == commit.hash,
                                graphColWidth: graphColWidth,
                                rowHeight: rowHeight
                            )
                            .onTapGesture {
                                Task { await vm.selectCommit(commit) }
                            }
                            .onHover { isHovered in
                                hoveredCommit = isHovered ? commit.hash : nil
                            }
                            .contextMenu {
                                commitContextMenu(for: commit)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func commitContextMenu(for commit: Commit) -> some View {
        Button("Checkout Commit") {
            Task { await vm.checkoutCommit(commit) }
        }
        Button("Revert Commit") {
            Task { await vm.revertCommit(commit) }
        }
        Divider()
        Button("Reset to Here (Soft)") {
            Task { await vm.resetToCommit(commit, mode: "soft") }
        }
        Button("Reset to Here (Mixed)") {
            Task { await vm.resetToCommit(commit, mode: "mixed") }
        }
        Button("Reset to Here (Hard)", role: .destructive) {
            Task { await vm.resetToCommit(commit, mode: "hard") }
        }
        Divider()
        Button("Copy Hash") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(commit.hash, forType: .string)
        }
        Button("Copy Short Hash") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(commit.shortHash, forType: .string)
        }
    }
}

// MARK: - Commit Row
struct CommitRow: View {
    let commit: Commit
    let isSelected: Bool
    let isHovered: Bool
    let graphColWidth: CGFloat
    let rowHeight: CGFloat

    private let columnColors = branchColors

    var body: some View {
        HStack(spacing: 0) {
            // Graph area
            GraphColumnView(
                commit: commit,
                colWidth: graphColWidth,
                height: rowHeight
            )
            .frame(width: graphWidth, height: effectiveHeight)

            // Commit info
            VStack(alignment: .leading, spacing: 4) {
                // Refs (branches / tags)
                if !commit.refs.filter({ !$0.isEmpty }).isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(commit.refs.filter { !$0.isEmpty }, id: \.self) { ref in
                                RefBadge(name: ref)
                            }
                        }
                        .padding(.top, 2)
                    }
                }

                // Message
                Text(commit.message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                // Meta
                HStack(spacing: 8) {
                    Text(commit.shortHash)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: "#00D4AA"))

                    Text("·")
                        .foregroundColor(.secondary)
                        .font(.caption2)

                    Text(commit.author)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Text("·")
                        .foregroundColor(.secondary)
                        .font(.caption2)

                    Text(commit.dateFormatted)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .frame(minHeight: rowHeight, alignment: .center)

            Spacer()
        }
        .background(
            isSelected
                ? Color(hex: "#00D4AA").opacity(0.1)
                : isHovered
                    ? Color.white.opacity(0.04)
                    : Color.clear
        )
        .overlay(
            Rectangle()
                .fill(isSelected ? Color(hex: "#00D4AA") : Color.clear)
                .frame(width: 2),
            alignment: .leading
        )
        .overlay(Divider().opacity(0.08), alignment: .bottom)
        .contentShape(Rectangle())
    }

    private var hasRefs: Bool {
        !commit.refs.filter { !$0.isEmpty }.isEmpty
    }

    private var effectiveHeight: CGFloat {
        hasRefs ? rowHeight + 18 : rowHeight
    }

    private var graphWidth: CGFloat {
        CGFloat(max(1, commit.graphColumn + 1)) * graphColWidth + 20
    }
}

// MARK: - Graph Column View
struct GraphColumnView: View {
    let commit: Commit
    let colWidth: CGFloat
    let height: CGFloat

    private let colors = branchColors

    var body: some View {
        Canvas { ctx, size in
            let col = commit.graphColumn
            let cx = colOffset(col) + colWidth / 2
            let cy = size.height / 2
            let nodeRadius: CGFloat = 4.5

            // Draw vertical line through commit column
            let lineColor = colors[col % colors.count]
            var linePath = Path()
            linePath.move(to: CGPoint(x: cx, y: 0))
            linePath.addLine(to: CGPoint(x: cx, y: size.height))
            ctx.stroke(linePath, with: .color(lineColor.opacity(0.4)), lineWidth: 1.5)

            // Draw node circle
            let nodeRect = CGRect(x: cx - nodeRadius, y: cy - nodeRadius,
                                  width: nodeRadius * 2, height: nodeRadius * 2)
            ctx.fill(Path(ellipseIn: nodeRect), with: .color(lineColor))

            // Inner dot for current HEAD commits
            let hasHEAD = commit.refs.contains { $0.contains("HEAD") }
            if hasHEAD {
                let innerRadius = nodeRadius - 2
                let innerRect = CGRect(x: cx - innerRadius, y: cy - innerRadius,
                                       width: innerRadius * 2, height: innerRadius * 2)
                ctx.fill(Path(ellipseIn: innerRect), with: .color(.white))
            }

            // Draw parent connections for multi-parent commits (merges)
            for (i, parentLine) in commit.graphLines.enumerated() {
                let pcx = colOffset(parentLine.column) + colWidth / 2
                if parentLine.column != col {
                    var mergePath = Path()
                    mergePath.move(to: CGPoint(x: cx, y: cy))
                    mergePath.addCurve(
                        to: CGPoint(x: pcx, y: size.height),
                        control1: CGPoint(x: cx, y: cy + 16),
                        control2: CGPoint(x: pcx, y: cy + 8)
                    )
                    let mergeColor = colors[parentLine.column % colors.count]
                    ctx.stroke(mergePath, with: .color(mergeColor.opacity(0.5)), lineWidth: 1.5)
                }
                _ = i
            }
        }
    }

    private func colOffset(_ col: Int) -> CGFloat {
        CGFloat(col) * colWidth + 8
    }
}

// MARK: - Ref Badge
struct RefBadge: View {
    let name: String

    private var isHead: Bool { name.contains("HEAD") }
    private var isTag: Bool { name.hasPrefix("tag:") }
    private var displayName: String {
        name.replacingOccurrences(of: "tag: ", with: "")
    }

    var badgeColor: Color {
        if isHead { return Color(hex: "#00D4AA") }
        if isTag { return Color(hex: "#FFD60A") }
        return Color(hex: "#5AC8FA")
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: isTag ? "tag.fill" : isHead ? "location.fill" : "arrow.triangle.branch")
                .font(.system(size: 7))
            Text(displayName)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .lineLimit(1)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(badgeColor.opacity(0.15))
        .foregroundColor(badgeColor)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(badgeColor.opacity(0.3), lineWidth: 0.5))
    }
}
