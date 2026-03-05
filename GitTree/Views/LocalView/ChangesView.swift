import SwiftUI

struct ChangesView: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var showCommitSheet: Bool
    @Binding var showStashSheet: Bool

    private var staged: [FileChange] { vm.changes.filter { $0.isStaged } }
    private var unstaged: [FileChange] { vm.changes.filter { !$0.isStaged } }

    var body: some View {
        VStack(spacing: 0) {
            if vm.changes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: "#3DD68C").opacity(0.6))
                    Text("Working tree clean")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text("No uncommitted changes")
                        .font(.caption)
                        .foregroundColor(Color.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#0D1117"))
            } else {
                // Action buttons
                HStack(spacing: 8) {
                    Button {
                        Task { await vm.stageAll() }
                    } label: {
                        Label("Stage All", systemImage: "plus.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(SmallActionButtonStyle(color: Color(hex: "#3DD68C")))

                    Button {
                        showStashSheet = true
                    } label: {
                        Label("Stash", systemImage: "tray.and.arrow.down.fill")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(SmallActionButtonStyle(color: .secondary))

                    Spacer()

                    Button {
                        showCommitSheet = true
                    } label: {
                        Label("Commit (\(staged.count))", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(SmallActionButtonStyle(color: Color(hex: "#5AC8FA"), filled: true))
                    .disabled(staged.isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(hex: "#161B22"))
                .overlay(Divider().opacity(0.2), alignment: .bottom)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Staged Section
                        if !staged.isEmpty {
                            ChangesSection(
                                title: "STAGED",
                                count: staged.count,
                                color: Color(hex: "#3DD68C")
                            )
                            ForEach(staged) { file in
                                FileChangeRow(file: file, onAction: { action in
                                    handleFileAction(action, file: file)
                                })
                            }
                        }

                        // Unstaged Section
                        if !unstaged.isEmpty {
                            ChangesSection(
                                title: "UNSTAGED",
                                count: unstaged.count,
                                color: Color(hex: "#F5A623")
                            )
                            ForEach(unstaged) { file in
                                FileChangeRow(file: file, onAction: { action in
                                    handleFileAction(action, file: file)
                                })
                            }
                        }
                    }
                }
            }
        }
        .background(Color(hex: "#0D1117"))
    }

    private func handleFileAction(_ action: FileChangeRow.Action, file: FileChange) {
        switch action {
        case .stage:
            Task { await vm.stageFile(file) }
        case .unstage:
            Task { await vm.unstageFile(file) }
        case .discard:
            Task { await vm.discardChanges(in: file) }
        case .viewDiff:
            Task { await vm.loadFileDiff(for: file) }
        }
    }
}

// MARK: - Changes Section Header
struct ChangesSection: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("(\(count))")
                    .font(.system(size: 9))
                    .foregroundColor(Color.secondary.opacity(0.7))
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(hex: "#161B22").opacity(0.6))
    }
}

// MARK: - File Change Row
struct FileChangeRow: View {
    @EnvironmentObject var vm: AppViewModel
    let file: FileChange
    let onAction: (Action) -> Void
    @State private var isHovered = false

    enum Action {
        case stage, unstage, discard, viewDiff
    }

    var body: some View {
        HStack(spacing: 8) {
            // Status Icon
            Image(systemName: file.status.icon)
                .font(.system(size: 11))
                .foregroundColor(file.status.color)
                .frame(width: 16)

            // Filename
            VStack(alignment: .leading, spacing: 2) {
                Text(file.filename)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(file.path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Status badge
            Text(file.status.label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(file.status.color)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(file.status.color.opacity(0.12))
                .cornerRadius(4)

            // Action buttons (on hover)
            if isHovered {
                HStack(spacing: 2) {
                    if file.isStaged {
                        iconButton("minus.circle", color: Color(hex: "#F5A623"), help: "Unstage") {
                            onAction(.unstage)
                        }
                    } else {
                        iconButton("plus.circle", color: Color(hex: "#3DD68C"), help: "Stage") {
                            onAction(.stage)
                        }
                        iconButton("trash", color: Color(hex: "#FF5A5A"), help: "Discard") {
                            onAction(.discard)
                        }
                    }
                    iconButton("doc.text.magnifyingglass", color: .secondary, help: "View Diff") {
                        onAction(.viewDiff)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isSelected
                ? Color(hex: "#5AC8FA").opacity(0.08)
                : isHovered
                    ? Color.white.opacity(0.04)
                    : Color.clear
        )
        .overlay(Divider().opacity(0.07), alignment: .bottom)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            onAction(.viewDiff)
        }
    }

    private var isSelected: Bool {
        vm.selectedFile?.id == file.id
    }

    @ViewBuilder
    private func iconButton(_ icon: String, color: Color, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
        }
        .buttonStyle(.plain)
        .frame(width: 24, height: 24)
        .background(color.opacity(0.1))
        .cornerRadius(5)
        .help(help)
    }
}

// MARK: - Small Action Button Style
struct SmallActionButtonStyle: ButtonStyle {
    let color: Color
    var filled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(filled ? color.opacity(0.9) : Color.white.opacity(0.05))
            .foregroundColor(filled ? .black : color)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(filled ? 0 : 0.3), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
