import SwiftUI

struct LocalRepositoryView: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var showNewBranchSheet: Bool
    @Binding var showCommitSheet: Bool
    @Binding var showStashSheet: Bool
    @Binding var showInitRepoSheet: Bool

    @State private var sidebarWidth: CGFloat = 220
    @State private var detailWidth: CGFloat = 340
    @State private var selectedPanel: LocalPanel = .history

    enum LocalPanel: String, CaseIterable {
        case history = "History"
        case changes = "Changes"
        case stash = "Stash"
    }

    var body: some View {
        if vm.currentRepo == nil {
            NoRepoView(
                showInitRepoSheet: $showInitRepoSheet,
                onOpenFolder: { vm.openFolderPicker() }
            )
        } else if let repo = vm.currentRepo, !repo.isGitRepo {
            NotGitRepoView(path: repo.path, showInitRepoSheet: $showInitRepoSheet)
        } else {
            HSplitView {
                // Left Sidebar: Branches + Stash
                BranchSidebar(showNewBranchSheet: $showNewBranchSheet)
                    .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)

                // Center: History / Changes / Stash panels
                VStack(spacing: 0) {
                    // Panel Selector
                    HStack(spacing: 0) {
                        ForEach(LocalPanel.allCases, id: \.self) { panel in
                            PanelTab(
                                title: panel.rawValue,
                                badge: panelBadge(for: panel),
                                isSelected: selectedPanel == panel
                            ) {
                                selectedPanel = panel
                            }
                        }
                        Spacer()

                        // Refresh button
                        Button {
                            Task { await vm.refreshAll() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 12)
                        .help("Refresh")
                    }
                    .frame(height: 36)
                    .background(Color(hex: "#161B22"))
                    .overlay(Divider().opacity(0.2), alignment: .bottom)

                    switch selectedPanel {
                    case .history:
                        CommitHistoryView()
                    case .changes:
                        ChangesView(
                            showCommitSheet: $showCommitSheet,
                            showStashSheet: $showStashSheet
                        )
                    case .stash:
                        StashView()
                    }
                }
                .frame(minWidth: 360, idealWidth: 480)

                // Right: Detail Panel
                DetailPanel()
                    .frame(minWidth: 280, idealWidth: 340, maxWidth: 500)
            }
        }
    }

    private func panelBadge(for panel: LocalPanel) -> Int? {
        switch panel {
        case .history: return nil
        case .changes:
            let count = vm.changes.count
            return count > 0 ? count : nil
        case .stash:
            let count = vm.stashes.count
            return count > 0 ? count : nil
        }
    }
}

// MARK: - No Repo View
struct NoRepoView: View {
    @Binding var showInitRepoSheet: Bool
    let onOpenFolder: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "internaldrive")
                .font(.system(size: 56))
                .foregroundColor(Color(hex: "#00D4AA").opacity(0.6))

            VStack(spacing: 8) {
                Text("No Repository Open")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text("Open an existing git repository or initialize a new one.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Open Folder") {
                    onOpenFolder()
                }
                .buttonStyle(GTButtonStyle(color: Color(hex: "#00D4AA")))

                Button("Initialize Repo") {
                    showInitRepoSheet = true
                }
                .buttonStyle(GTButtonStyle(color: Color(hex: "#5AC8FA"), filled: false))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#0D1117"))
    }
}

// MARK: - Not Git Repo View
struct NotGitRepoView: View {
    let path: String
    @Binding var showInitRepoSheet: Bool
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#F5A623"))

            VStack(spacing: 8) {
                Text("Not a Git Repository")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text(path)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Text("This folder is not a git repository. Initialize it to start tracking changes.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Initialize Here") {
                    Task { await vm.initRepository(at: path) }
                }
                .buttonStyle(GTButtonStyle(color: Color(hex: "#00D4AA")))

                Button("Open Different Folder") {
                    vm.openFolderPicker()
                }
                .buttonStyle(GTButtonStyle(color: Color(hex: "#5AC8FA"), filled: false))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#0D1117"))
    }
}

// MARK: - Panel Tab
struct PanelTab: View {
    let title: String
    let badge: Int?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                if let count = badge {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color(hex: "#00D4AA").opacity(0.2))
                        .foregroundColor(Color(hex: "#00D4AA"))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .foregroundColor(isSelected ? .white : .secondary)
            .overlay(
                Rectangle()
                    .fill(isSelected ? Color(hex: "#00D4AA") : Color.clear)
                    .frame(height: 2),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detail Panel
struct DetailPanel: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if let commit = vm.selectedCommit {
                    Text("Commit Details")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(commit.shortHash)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "#00D4AA"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#00D4AA").opacity(0.1))
                        .cornerRadius(4)
                } else if let file = vm.selectedFile {
                    Text(file.filename)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text(file.isStaged ? "STAGED" : "UNSTAGED")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(file.isStaged ? Color(hex: "#3DD68C") : Color(hex: "#F5A623"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((file.isStaged ? Color(hex: "#3DD68C") : Color(hex: "#F5A623")).opacity(0.1))
                        .cornerRadius(4)
                } else {
                    Text("Select a commit or file")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Color(hex: "#161B22"))
            .overlay(Divider().opacity(0.2), alignment: .bottom)

            if let commit = vm.selectedCommit {
                CommitDetailView(commit: commit)
            } else if let _ = vm.selectedFile {
                DiffView(diffText: vm.fileDiff)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Select a commit or file to see details")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#0D1117"))
            }
        }
        .background(Color(hex: "#0D1117"))
        .overlay(Divider().opacity(0.2), alignment: .leading)
    }
}

// MARK: - GT Button Style
struct GTButtonStyle: ButtonStyle {
    let color: Color
    var filled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(filled ? color.opacity(configuration.isPressed ? 0.8 : 1.0) : Color.clear)
            .foregroundColor(filled ? .black : color)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.6), lineWidth: filled ? 0 : 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
