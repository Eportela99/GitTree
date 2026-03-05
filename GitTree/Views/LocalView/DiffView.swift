import SwiftUI

struct DiffView: View {
    let diffText: String

    private var lines: [DiffLine] {
        diffText.components(separatedBy: "\n").map { line in
            DiffLine(
                text: line,
                type: classifyLine(line)
            )
        }
    }

    var body: some View {
        if diffText.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("No diff available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "#0D1117"))
        } else {
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        DiffLineView(line: line)
                    }
                }
                .padding(.bottom, 12)
            }
            .background(Color(hex: "#0A0D13"))
            .font(.system(size: 11, design: .monospaced))
        }
    }

    private func classifyLine(_ line: String) -> DiffLine.LineType {
        if line.hasPrefix("+++") || line.hasPrefix("---") { return .header }
        if line.hasPrefix("@@") { return .hunk }
        if line.hasPrefix("+") { return .added }
        if line.hasPrefix("-") { return .removed }
        if line.hasPrefix("diff ") || line.hasPrefix("index ") || line.hasPrefix("new file") { return .meta }
        return .context
    }
}

// MARK: - Diff Line
struct DiffLine: Identifiable {
    let id = UUID()
    let text: String
    let type: LineType

    enum LineType {
        case added, removed, hunk, header, meta, context
    }
}

struct DiffLineView: View {
    let line: DiffLine

    var body: some View {
        HStack(spacing: 0) {
            // Gutter
            Rectangle()
                .fill(gutterColor)
                .frame(width: 3)

            // Line number / indicator
            Text(indicator)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(indicatorColor.opacity(0.7))
                .frame(width: 16, alignment: .center)

            // Content
            Text(displayText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(textColor)
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: lineHeight)
        .background(bgColor)
        .textSelection(.enabled)
    }

    private var displayText: String {
        switch line.type {
        case .hunk: return line.text
        default: return line.text
        }
    }

    private var bgColor: Color {
        switch line.type {
        case .added: return Color(hex: "#3DD68C").opacity(0.1)
        case .removed: return Color(hex: "#FF5A5A").opacity(0.1)
        case .hunk: return Color(hex: "#5AC8FA").opacity(0.06)
        case .header, .meta: return Color.white.opacity(0.03)
        case .context: return Color.clear
        }
    }

    private var textColor: Color {
        switch line.type {
        case .added: return Color(hex: "#3DD68C")
        case .removed: return Color(hex: "#FF5A5A")
        case .hunk: return Color(hex: "#5AC8FA")
        case .header, .meta: return .secondary
        case .context: return Color.white.opacity(0.8)
        }
    }

    private var gutterColor: Color {
        switch line.type {
        case .added: return Color(hex: "#3DD68C").opacity(0.6)
        case .removed: return Color(hex: "#FF5A5A").opacity(0.6)
        default: return Color.clear
        }
    }

    private var indicatorColor: Color {
        switch line.type {
        case .added: return Color(hex: "#3DD68C")
        case .removed: return Color(hex: "#FF5A5A")
        default: return .secondary
        }
    }

    private var indicator: String {
        switch line.type {
        case .added: return "+"
        case .removed: return "-"
        default: return ""
        }
    }

    private var lineHeight: CGFloat {
        switch line.type {
        case .hunk, .header, .meta: return 22
        default: return 18
        }
    }
}
