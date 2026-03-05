import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showNewBranchSheet = false
    @State private var showCommitSheet = false
    @State private var showStashSheet = false
    @State private var showCreateRepoSheet = false
    @State private var showInitRepoSheet = false

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color(hex: "#0D1117").ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Toolbar
                TopToolbar(
                    showNewBranchSheet: $showNewBranchSheet,
                    showCommitSheet: $showCommitSheet,
                    showStashSheet: $showStashSheet,
                    showCreateRepoSheet: $showCreateRepoSheet,
                    showInitRepoSheet: $showInitRepoSheet
                )

                Divider().opacity(0.2)

                // Tab Content
                ZStack {
                    switch vm.selectedTab {
                    case .home:
                        HomeView()
                    case .local:
                        LocalRepositoryView(
                            showNewBranchSheet: $showNewBranchSheet,
                            showCommitSheet: $showCommitSheet,
                            showStashSheet: $showStashSheet,
                            showInitRepoSheet: $showInitRepoSheet
                        )
                    case .github:
                        GitHubView(showCreateRepoSheet: $showCreateRepoSheet)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Status Bar
                StatusBar()
            }
        }
        .sheet(isPresented: $showNewBranchSheet) {
            NewBranchSheet()
        }
        .sheet(isPresented: $showCommitSheet) {
            CommitSheet()
        }
        .sheet(isPresented: $showStashSheet) {
            StashSheet()
        }
        .sheet(isPresented: $showCreateRepoSheet) {
            CreateRepoSheet(isPresented: $showCreateRepoSheet)
        }
        .sheet(isPresented: $showInitRepoSheet) {
            InitRepoSheet(isPresented: $showInitRepoSheet)
        }
        .onAppear {
            if vm.showFolderPicker { vm.openFolderPicker() }
        }
        .onChange(of: vm.showFolderPicker) { show in
            if show {
                vm.showFolderPicker = false
                vm.openFolderPicker()
            }
        }
        .alert("Administrator Privileges Required", isPresented: $vm.showAdminPrompt) {
            Button("Allow", role: .destructive) {
                if let action = vm.adminPromptAction {
                    Task { await action() }
                    vm.adminPromptAction = nil
                }
            }
            Button("Cancel", role: .cancel) {
                vm.adminPromptAction = nil
            }
        } message: {
            Text("This git operation requires administrator access.\n\n\(vm.adminPromptCommand)\n\nmacOS will ask for your password.")
        }
    }
}

// MARK: - Top Toolbar
struct TopToolbar: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var showNewBranchSheet: Bool
    @Binding var showCommitSheet: Bool
    @Binding var showStashSheet: Bool
    @Binding var showCreateRepoSheet: Bool
    @Binding var showInitRepoSheet: Bool

    var body: some View {
        HStack(spacing: 0) {
            // App Logo + Name
            HStack(spacing: 8) {
                Image("AppIcon")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .cornerRadius(5)
                Text("GitTree")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)

            Divider().frame(height: 20).opacity(0.3)

            // Tab Buttons
            HStack(spacing: 2) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    TabButton(tab: tab, isSelected: vm.selectedTab == tab) {
                        vm.selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 8)

            Divider().frame(height: 20).opacity(0.3)

            // Context Actions
            if vm.selectedTab == .local, let repo = vm.currentRepo {
                HStack(spacing: 4) {
                    // Repo name
                    HStack(spacing: 4) {
                        Image(systemName: "internaldrive.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(repo.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)

                    if repo.isGitRepo {
                        Divider().frame(height: 16).opacity(0.3)

                        ToolbarButton(icon: "folder.badge.plus", label: "Open") {
                            vm.openFolderPicker()
                        }
                        ToolbarButton(icon: "arrow.down.to.line", label: "Fetch") {
                            Task { await vm.fetch() }
                        }
                        ToolbarButton(icon: "arrow.down.circle", label: "Pull") {
                            Task { await vm.pull() }
                        }
                        ToolbarButton(icon: "arrow.up.circle", label: "Push") {
                            Task { await vm.push() }
                        }

                        Divider().frame(height: 16).opacity(0.3)

                        ToolbarButton(icon: "plus.circle.fill", label: "Branch", tint: Color(hex: "#00D4AA")) {
                            showNewBranchSheet = true
                        }
                        ToolbarButton(icon: "checkmark.circle.fill", label: "Commit", tint: Color(hex: "#5AC8FA")) {
                            showCommitSheet = true
                        }
                        ToolbarButton(icon: "tray.and.arrow.down.fill", label: "Stash") {
                            showStashSheet = true
                        }
                    }
                }
                .padding(.horizontal, 8)
            } else if vm.selectedTab == .github {
                HStack(spacing: 4) {
                    ToolbarButton(icon: "plus.circle.fill", label: "New Repo", tint: Color(hex: "#00D4AA")) {
                        showCreateRepoSheet = true
                    }
                    ToolbarButton(icon: "arrow.clockwise", label: "Refresh") {
                        Task { await vm.loadGitHubRepos() }
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer()

            // Loading Indicator
            if vm.isLoading {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                    Text(vm.loadingMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
            }

            // Messages
            if let err = vm.errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color(hex: "#FF5A5A"))
                        .font(.caption)
                    Text(err)
                        .font(.caption)
                        .foregroundColor(Color(hex: "#FF5A5A"))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
            }

            if let success = vm.successMessage {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#3DD68C"))
                        .font(.caption)
                    Text(success)
                        .font(.caption)
                        .foregroundColor(Color(hex: "#3DD68C"))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
            }
        }
        .frame(height: 44)
        .background(Color(hex: "#161B22"))
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? Color(hex: "#00D4AA").opacity(0.15)
                    : Color.clear
            )
            .foregroundColor(isSelected ? Color(hex: "#00D4AA") : .secondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color(hex: "#00D4AA").opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toolbar Button
struct ToolbarButton: View {
    let icon: String
    let label: String
    var tint: Color = .secondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 9))
            }
            .frame(width: 44, height: 34)
            .foregroundColor(tint)
            .background(Color.white.opacity(0.0))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(label)
    }
}

// MARK: - Status Bar
struct StatusBar: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        HStack(spacing: 12) {
            if let repo = vm.currentRepo {
                // Branch indicator
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                    Text(repo.currentBranch.isEmpty ? "detached HEAD" : repo.currentBranch)
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundColor(Color(hex: "#00D4AA"))

                if repo.aheadCount > 0 || repo.behindCount > 0 {
                    HStack(spacing: 4) {
                        if repo.aheadCount > 0 {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 9))
                            Text("\(repo.aheadCount)")
                                .font(.caption2)
                        }
                        if repo.behindCount > 0 {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 9))
                            Text("\(repo.behindCount)")
                                .font(.caption2)
                        }
                    }
                    .foregroundColor(.secondary)
                }

                Divider().frame(height: 12).opacity(0.3)

                // Changes count
                let stagedCount = vm.changes.filter { $0.isStaged }.count
                let unstagedCount = vm.changes.filter { !$0.isStaged }.count

                if stagedCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "#3DD68C"))
                        Text("\(stagedCount) staged")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                if unstagedCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "#F5A623"))
                        Text("\(unstagedCount) unstaged")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // GitHub auth status
            HStack(spacing: 4) {
                Circle()
                    .fill(vm.isGitHubAuthenticated ? Color(hex: "#3DD68C") : Color(hex: "#FF5A5A"))
                    .frame(width: 6, height: 6)
                Text(vm.gitHubUsername.map { "@\($0)" } ?? "Not signed in")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background(Color(hex: "#0D1117"))
        .overlay(Divider().opacity(0.2), alignment: .top)
    }
}

// MARK: - New Branch Sheet
struct NewBranchSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss
    @State private var branchName = ""
    @State private var checkoutAfter = true

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "New Branch", icon: "arrow.triangle.branch")

            VStack(spacing: 16) {
                GTTextField(label: "Branch Name", text: $branchName, placeholder: "feature/my-feature")

                Toggle("Checkout after creating", isOn: $checkoutAfter)
                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#00D4AA")))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                if let currentBranch = vm.currentRepo?.currentBranch {
                    Text("Branching from: \(currentBranch)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)

            SheetFooter(confirmLabel: "Create Branch", isEnabled: !branchName.isEmpty) {
                Task {
                    await vm.createBranch(name: branchName, checkout: checkoutAfter)
                    dismiss()
                }
            } onCancel: {
                dismiss()
            }
        }
        .frame(width: 380)
        .background(Color(hex: "#161B22"))
    }
}

// MARK: - Commit Sheet
struct CommitSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss
    @State private var commitMessage = ""
    @State private var commitBody = ""

    private var staged: [FileChange] { vm.changes.filter { $0.isStaged } }
    private var unstaged: [FileChange] { vm.changes.filter { !$0.isStaged } }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Commit Changes", icon: "checkmark.circle.fill")

            ScrollView {
                VStack(spacing: 16) {
                    GTTextField(label: "Commit Message", text: $commitMessage, placeholder: "Describe your changes...")

                    // Staged files
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Staged (\(staged.count))", systemImage: "plus.circle.fill")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#3DD68C"))

                        if staged.isEmpty {
                            Text("No staged changes. Stage files in the Changes panel.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(staged) { file in
                                HStack(spacing: 6) {
                                    Image(systemName: file.status.icon)
                                        .foregroundColor(file.status.color)
                                        .font(.caption)
                                    Text(file.filename)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(file.status.label)
                                        .font(.caption2)
                                        .foregroundColor(file.status.color)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(8)

                    // Quick stage all
                    if !unstaged.isEmpty {
                        Button {
                            Task { await vm.stageAll() }
                        } label: {
                            Label("Stage All Unstaged (\(unstaged.count))", systemImage: "plus.circle")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#00D4AA"))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }

            SheetFooter(
                confirmLabel: "Commit",
                isEnabled: !commitMessage.isEmpty && !staged.isEmpty
            ) {
                Task {
                    await vm.makeCommit(message: commitMessage)
                    dismiss()
                }
            } onCancel: {
                dismiss()
            }
        }
        .frame(width: 440, height: 480)
        .background(Color(hex: "#161B22"))
    }
}

// MARK: - Stash Sheet
struct StashSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) var dismiss
    @State private var message = ""

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Stash Changes", icon: "tray.and.arrow.down.fill")

            VStack(spacing: 16) {
                GTTextField(label: "Stash Message (optional)", text: $message, placeholder: "Work in progress...")

                Text("This will save all uncommitted changes to the stash.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)

            SheetFooter(confirmLabel: "Stash") {
                Task {
                    await vm.stashChanges(message: message.isEmpty ? nil : message)
                    dismiss()
                }
            } onCancel: {
                dismiss()
            }
        }
        .frame(width: 380)
        .background(Color(hex: "#161B22"))
    }
}

// MARK: - Init Repo Sheet
struct InitRepoSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var isPresented: Bool
    @State private var selectedPath = ""

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Initialize Repository", icon: "externaldrive.badge.plus")

            VStack(spacing: 16) {
                HStack {
                    Text(selectedPath.isEmpty ? "No folder selected" : selectedPath)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(selectedPath.isEmpty ? .secondary : .primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        if panel.runModal() == .OK, let url = panel.url {
                            selectedPath = url.path
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Text("This will run `git init` in the selected folder.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)

            SheetFooter(confirmLabel: "Initialize", isEnabled: !selectedPath.isEmpty) {
                isPresented = false
                Task { await vm.initRepository(at: selectedPath) }
            } onCancel: {
                isPresented = false
            }
        }
        .frame(width: 440)
        .background(Color(hex: "#161B22"))
    }
}

// MARK: - Reusable Sheet Components
struct SheetHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#00D4AA"))
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(hex: "#0D1117"))
        .overlay(Divider().opacity(0.2), alignment: .bottom)
    }
}

struct SheetFooter: View {
    let confirmLabel: String
    var isEnabled: Bool = true
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button("Cancel", action: onCancel)
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape)
            Button(confirmLabel, action: onConfirm)
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#00D4AA"))
                .disabled(!isEnabled)
                .keyboardShortcut(.return)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(hex: "#0D1117"))
        .overlay(Divider().opacity(0.2), alignment: .top)
    }
}

struct GTTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}
