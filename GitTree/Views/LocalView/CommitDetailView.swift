import SwiftUI

struct CommitDetailView: View {
    @EnvironmentObject var vm: AppViewModel
    let commit: Commit

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Commit Header Card
                VStack(alignment: .leading, spacing: 12) {
                    // Message
                    Text(commit.message)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    // Meta Grid
                    VStack(spacing: 6) {
                        MetaRow(icon: "person.fill", label: "Author", value: "\(commit.author) <\(commit.email)>")
                        MetaRow(icon: "calendar", label: "Date", value: commit.dateFormatted)
                        MetaRow(icon: "number", label: "Hash", value: commit.hash, mono: true, copyable: true)
                        if !commit.parentHashes.isEmpty {
                            MetaRow(icon: "arrow.up", label: "Parents",
                                    value: commit.parentHashes.map { String($0.prefix(7)) }.joined(separator: ", "),
                                    mono: true)
                        }
                    }

                    // Refs
                    if !commit.refs.filter({ !$0.isEmpty }).isEmpty {
                        HStack(spacing: 4) {
                            Text("Refs:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(commit.refs.filter { !$0.isEmpty }, id: \.self) { ref in
                                RefBadge(name: ref)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.03))
                .cornerRadius(10)
                .padding(14)

                // Action Buttons
                HStack(spacing: 8) {
                    CommitActionBtn(icon: "arrow.uturn.left.circle", label: "Revert", color: Color(hex: "#F5A623")) {
                        Task { await vm.revertCommit(commit) }
                    }
                    CommitActionBtn(icon: "point.topleft.down.to.point.bottomright.curvepath", label: "Checkout", color: Color(hex: "#5AC8FA")) {
                        Task { await vm.checkoutCommit(commit) }
                    }
                    CommitActionBtn(icon: "doc.on.doc", label: "Copy Hash", color: .secondary) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(commit.hash, forType: .string)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

                Divider().opacity(0.15).padding(.horizontal, 14)

                // Diff
                VStack(alignment: .leading, spacing: 8) {
                    Text("CHANGES")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)

                    DiffView(diffText: vm.commitDiff)
                }
            }
        }
        .background(Color(hex: "#0D1117"))
    }
}

// MARK: - Meta Row
struct MetaRow: View {
    let icon: String
    let label: String
    let value: String
    var mono: Bool = false
    var copyable: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 14)
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: mono ? .monospaced : .default))
                .foregroundColor(.primary)
                .lineLimit(2)
                .textSelection(.enabled)
            Spacer()
            if copyable {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Commit Action Button
struct CommitActionBtn: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundColor(color)
            .background(color.opacity(0.1))
            .cornerRadius(7)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(color.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
