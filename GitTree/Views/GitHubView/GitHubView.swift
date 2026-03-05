import SwiftUI

struct GitHubView: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var showCreateRepoSheet: Bool

    var body: some View {
        if !vm.isGitHubAuthenticated {
            GitHubAuthView()
        } else {
            HStack(spacing: 0) {
                // Left Sidebar: User Profile + Section Nav
                GitHubSidebar(showCreateRepoSheet: $showCreateRepoSheet)
                    .frame(width: 220)

                Divider().opacity(0.2)

                // Main Content
                VStack(spacing: 0) {
                    // Section Header
                    HStack {
                        Text(vm.gitHubSection.rawValue.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)

                        Spacer()

                        if vm.selectedGitHubRepo != nil {
                            Button {
                                vm.selectedGitHubRepo = nil
                            } label: {
                                Label("All Repos", systemImage: "chevron.left")
                                    .font(.caption)
                                    .foregroundColor(Color(hex: "#00D4AA"))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(Color(hex: "#161B22"))
                    .overlay(Divider().opacity(0.2), alignment: .bottom)

                    switch vm.gitHubSection {
                    case .repositories:
                        RepoListView(showCreateRepoSheet: $showCreateRepoSheet)
                    case .pullRequests:
                        PRListView()
                    case .issues:
                        IssueListView()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .onAppear {
                if vm.gitHubRepos.isEmpty {
                    Task { await vm.loadGitHubRepos() }
                }
            }
        }
    }
}

// MARK: - GitHub Auth View
struct GitHubAuthView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var isTesting = false

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "network")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#BF5AF2").opacity(0.7))

            VStack(spacing: 10) {
                Text("Connect to GitHub")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Authenticate with GitHub CLI to manage repositories,\npull requests, and issues.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    InstructionStep(
                        number: "1",
                        title: "Install GitHub CLI",
                        code: "brew install gh"
                    )
                    InstructionStep(
                        number: "2",
                        title: "Authenticate",
                        code: "gh auth login"
                    )
                }

                Button {
                    isTesting = true
                    Task {
                        await vm.checkGitHubAuth()
                        isTesting = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isTesting {
                            ProgressView().scaleEffect(0.7).frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "arrow.clockwise.circle.fill")
                        }
                        Text("Test Connection")
                            .fontWeight(.semibold)
                    }
                    .frame(width: 200)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#00D4AA").opacity(0.9))
                    .foregroundColor(.black)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(isTesting)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#0D1117"))
    }
}

// MARK: - Instruction Step
struct InstructionStep: View {
    let number: String
    let title: String
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(number)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 18, height: 18)
                    .background(Color(hex: "#00D4AA"))
                    .cornerRadius(9)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text(code)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(hex: "#3DD68C"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .padding(12)
        .frame(width: 180)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }
}

// MARK: - GitHub Sidebar
struct GitHubSidebar: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var showCreateRepoSheet: Bool

    var body: some View {
        VStack(spacing: 0) {
            // User Profile
            if let user = vm.gitHubUser {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#BF5AF2").opacity(0.15))
                            .frame(width: 56, height: 56)
                        Text(String(user.login.prefix(2)).uppercased())
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#BF5AF2"))
                    }

                    VStack(spacing: 3) {
                        Text("@\(user.login)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        if let name = user.name, !name.isEmpty {
                            Text(name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: 14) {
                        UserStat(count: user.publicRepos, label: "Repos")
                        UserStat(count: user.followers, label: "Followers")
                        UserStat(count: user.following, label: "Following")
                    }
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#161B22"))
                .overlay(Divider().opacity(0.2), alignment: .bottom)
            }

            // Section Navigation
            VStack(spacing: 2) {
                ForEach(AppViewModel.GitHubSection.allCases, id: \.self) { section in
                    GitHubNavButton(
                        section: section,
                        isSelected: vm.gitHubSection == section
                    ) {
                        vm.gitHubSection = section
                        if let repo = vm.selectedGitHubRepo {
                            switch section {
                            case .pullRequests:
                                Task { await vm.loadPullRequests(for: repo) }
                            case .issues:
                                Task { await vm.loadIssues(for: repo) }
                            case .repositories:
                                break
                            }
                        }
                    }
                }
            }
            .padding(8)

            Spacer()

            // Bottom Actions
            VStack(spacing: 6) {
                Divider().opacity(0.2)

                Button {
                    showCreateRepoSheet = true
                } label: {
                    Label("New Repository", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundColor(Color(hex: "#00D4AA"))
                        .background(Color(hex: "#00D4AA").opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)

                Button {
                    Task { await vm.checkGitHubAuth() }
                } label: {
                    Label("Refresh Auth", systemImage: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)
            }
        }
        .background(Color(hex: "#161B22"))
        .overlay(Divider().opacity(0.2), alignment: .trailing)
    }
}

// MARK: - User Stat
struct UserStat: View {
    let count: Int
    let label: String

    var body: some View {
        VStack(spacing: 1) {
            Text("\(count)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - GitHub Nav Button
struct GitHubNavButton: View {
    let section: AppViewModel.GitHubSection
    let isSelected: Bool
    let action: () -> Void

    private var icon: String {
        switch section {
        case .repositories: return "books.vertical.fill"
        case .pullRequests: return "arrow.triangle.pull"
        case .issues: return "exclamationmark.circle.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? Color(hex: "#00D4AA") : .secondary)
                    .frame(width: 20)
                Text(section.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color(hex: "#00D4AA").opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color(hex: "#00D4AA").opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PR List View
struct PRListView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let repo = vm.selectedGitHubRepo {
                if vm.pullRequests.isEmpty {
                    EmptyGitHubState(
                        icon: "arrow.triangle.pull",
                        title: "No Pull Requests",
                        subtitle: "No open pull requests for \(repo.name)"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(vm.pullRequests) { pr in
                                PRRow(pr: pr, repoFullName: repo.fullName)
                            }
                        }
                        .padding(12)
                    }
                }
            } else {
                EmptyGitHubState(
                    icon: "arrow.triangle.pull",
                    title: "Select a Repository",
                    subtitle: "Choose a repo to see its pull requests"
                )
            }
        }
        .background(Color(hex: "#0D1117"))
    }
}

// MARK: - PR Row
struct PRRow: View {
    @EnvironmentObject var vm: AppViewModel
    let pr: PullRequest
    let repoFullName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: pr.isDraft ? "doc.circle" : "arrow.triangle.pull")
                .font(.system(size: 14))
                .foregroundColor(pr.isDraft ? .secondary : Color(hex: "#3DD68C"))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("#\(pr.number)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text(pr.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if pr.isDraft {
                        DraftBadge()
                    }
                }
                HStack(spacing: 8) {
                    Text("\(pr.headBranch) → \(pr.baseBranch)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text("by @\(pr.author)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(pr.createdAt)
                        .font(.caption2)
                        .foregroundColor(Color.secondary.opacity(0.7))
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Button("Merge") {
                    Task { try? await vm.github.mergePR(number: pr.number, repo: repoFullName) }
                }
                .buttonStyle(SmallActionButtonStyle(color: Color(hex: "#3DD68C"), filled: true))
                .font(.system(size: 10))

                Button("Open") {
                    Task { try? await vm.github.openPRInBrowser(number: pr.number, repo: repoFullName) }
                }
                .buttonStyle(SmallActionButtonStyle(color: .secondary))
                .font(.system(size: 10))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.02))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

struct DraftBadge: View {
    var body: some View {
        Text("DRAFT")
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(3)
    }
}

// MARK: - Issue List View
struct IssueListView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showCreateIssueSheet = false

    var body: some View {
        VStack(spacing: 0) {
            if let repo = vm.selectedGitHubRepo {
                // Toolbar
                HStack {
                    Button {
                        showCreateIssueSheet = true
                    } label: {
                        Label("New Issue", systemImage: "plus")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(SmallActionButtonStyle(color: Color(hex: "#00D4AA"), filled: true))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(hex: "#161B22"))
                .overlay(Divider().opacity(0.2), alignment: .bottom)

                if vm.issues.isEmpty {
                    EmptyGitHubState(
                        icon: "exclamationmark.circle",
                        title: "No Issues",
                        subtitle: "No open issues for \(repo.name)"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(vm.issues) { issue in
                                IssueRow(issue: issue, repoFullName: repo.fullName)
                            }
                        }
                        .padding(12)
                    }
                }
            } else {
                EmptyGitHubState(
                    icon: "exclamationmark.circle",
                    title: "Select a Repository",
                    subtitle: "Choose a repo to see its issues"
                )
            }
        }
        .background(Color(hex: "#0D1117"))
        .sheet(isPresented: $showCreateIssueSheet) {
            if let repo = vm.selectedGitHubRepo {
                CreateIssueSheet(isPresented: $showCreateIssueSheet, repo: repo)
            }
        }
    }
}

// MARK: - Issue Row
struct IssueRow: View {
    @EnvironmentObject var vm: AppViewModel
    let issue: GitHubIssue
    let repoFullName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#3DD68C"))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("#\(issue.number)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text(issue.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text("by @\(issue.author)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(issue.createdAt)
                        .font(.caption2)
                        .foregroundColor(Color.secondary.opacity(0.7))
                    ForEach(issue.labels.prefix(3), id: \.self) { label in
                        Text(label)
                            .font(.system(size: 9))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color(hex: "#5AC8FA").opacity(0.15))
                            .foregroundColor(Color(hex: "#5AC8FA"))
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            Button("Close") {
                Task { try? await vm.github.closeIssue(number: issue.number, repo: repoFullName) }
            }
            .buttonStyle(SmallActionButtonStyle(color: Color(hex: "#FF5A5A")))
            .font(.system(size: 10))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.02))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - Create Issue Sheet
struct CreateIssueSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var isPresented: Bool
    let repo: GitHubRepo
    @State private var title = ""
    @State private var body_ = ""

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "New Issue · \(repo.name)", icon: "exclamationmark.circle.fill")
            VStack(spacing: 16) {
                GTTextField(label: "Title", text: $title, placeholder: "Bug: something is broken")
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description (optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $body_)
                        .font(.system(size: 13))
                        .frame(height: 100)
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .scrollContentBackground(.hidden)
                }
            }
            .padding(20)

            SheetFooter(confirmLabel: "Create Issue", isEnabled: !title.isEmpty) {
                isPresented = false
                Task { try? await vm.github.createIssue(title: title, body: body_, repo: repo.fullName) }
            } onCancel: {
                isPresented = false
            }
        }
        .frame(width: 440)
        .background(Color(hex: "#161B22"))
    }
}

// MARK: - Empty State
struct EmptyGitHubState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text(title)
                .font(.callout)
                .foregroundColor(.secondary)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(Color.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#0D1117"))
    }
}
