import SwiftUI

struct RepoListView: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var showCreateRepoSheet: Bool
    @State private var searchText = ""
    @State private var sortBy: SortOption = .updated
    @State private var filterPrivate: Bool? = nil
    @State private var repoToDelete: GitHubRepo?
    @State private var showDeleteConfirm = false

    enum SortOption: String, CaseIterable {
        case updated = "Updated"
        case name = "Name"
        case stars = "Stars"
    }

    private var filteredRepos: [GitHubRepo] {
        var repos = vm.gitHubRepos

        if let priv = filterPrivate {
            repos = repos.filter { $0.isPrivate == priv }
        }

        if !searchText.isEmpty {
            repos = repos.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        switch sortBy {
        case .updated: break
        case .name: repos.sort { $0.name.lowercased() < $1.name.lowercased() }
        case .stars: repos.sort { $0.stars > $1.stars }
        }

        return repos
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Search repositories...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.05))
                .cornerRadius(7)
                .frame(maxWidth: 220)

                // Filter
                Picker("", selection: $filterPrivate) {
                    Text("All").tag(nil as Bool?)
                    Text("Public").tag(false as Bool?)
                    Text("Private").tag(true as Bool?)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)

                Spacer()

                // Sort
                Picker("Sort", selection: $sortBy) {
                    ForEach(SortOption.allCases, id: \.self) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)

                // Refresh
                Button {
                    Task { await vm.loadGitHubRepos() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(hex: "#161B22"))
            .overlay(Divider().opacity(0.2), alignment: .bottom)

            // Content
            if vm.isLoading && vm.gitHubRepos.isEmpty {
                Spacer()
                ProgressView("Loading repositories...")
                    .foregroundColor(.secondary)
                Spacer()
            } else if filteredRepos.isEmpty {
                EmptyGitHubState(
                    icon: "books.vertical",
                    title: "No Repositories Found",
                    subtitle: searchText.isEmpty ? "Create your first repository" : "No results for '\(searchText)'"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredRepos) { repo in
                            RepoCard(repo: repo) { action in
                                handleRepoAction(action, repo: repo)
                            }
                        }
                    }
                    .padding(12)
                }
                .background(Color(hex: "#0D1117"))
            }
        }
        .confirmationDialog(
            "Delete \"\(repoToDelete?.name ?? "")\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Repository", role: .destructive) {
                if let repo = repoToDelete {
                    Task { await vm.deleteGitHubRepo(repo) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the repository and all its data on GitHub. This cannot be undone.")
        }
    }

    private func handleRepoAction(_ action: RepoCard.Action, repo: GitHubRepo) {
        switch action {
        case .clone:
            Task { await vm.cloneGitHubRepo(repo) }
        case .open:
            Task { try? await vm.github.openInBrowser(fullName: repo.fullName) }
        case .delete:
            repoToDelete = repo
            showDeleteConfirm = true
        case .viewPRs:
            vm.selectedGitHubRepo = repo
            vm.gitHubSection = .pullRequests
            Task { await vm.loadPullRequests(for: repo) }
        case .viewIssues:
            vm.selectedGitHubRepo = repo
            vm.gitHubSection = .issues
            Task { await vm.loadIssues(for: repo) }
        case .selectForLocal:
            Task { await vm.cloneGitHubRepo(repo) }
        }
    }
}

// MARK: - Repo Card
struct RepoCard: View {
    @EnvironmentObject var vm: AppViewModel
    let repo: GitHubRepo
    let onAction: (Action) -> Void
    @State private var isHovered = false

    enum Action {
        case clone, open, delete, viewPRs, viewIssues, selectForLocal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                // Repo Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(repo.isPrivate
                              ? Color(hex: "#BF5AF2").opacity(0.12)
                              : Color(hex: "#00D4AA").opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: repo.isForked ? "arrow.triangle.branch" : (repo.isPrivate ? "lock.fill" : "books.vertical.fill"))
                        .font(.system(size: 16))
                        .foregroundColor(repo.isPrivate ? Color(hex: "#BF5AF2") : Color(hex: "#00D4AA"))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(repo.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)

                        if repo.isPrivate {
                            Text("PRIVATE")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color(hex: "#BF5AF2").opacity(0.2))
                                .foregroundColor(Color(hex: "#BF5AF2"))
                                .cornerRadius(4)
                        }

                        if repo.isForked {
                            Text("FORK")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color(hex: "#F5A623").opacity(0.2))
                                .foregroundColor(Color(hex: "#F5A623"))
                                .cornerRadius(4)
                        }
                    }

                    if let desc = repo.description {
                        Text(desc)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 10) {
                        if let lang = repo.language {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(repo.languageColor)
                                    .frame(width: 8, height: 8)
                                Text(lang)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(Color(hex: "#FFD60A"))
                            Text("\(repo.stars)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                            Text("\(repo.forks)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("Updated \(repo.updatedAt)")
                            .font(.caption2)
                            .foregroundColor(Color.secondary.opacity(0.7))
                    }
                }

                Spacer()

                // Action Buttons (on hover)
                if isHovered {
                    HStack(spacing: 4) {
                        Button("Clone") { onAction(.clone) }
                            .buttonStyle(SmallActionButtonStyle(color: Color(hex: "#00D4AA"), filled: true))
                            .font(.system(size: 10))

                        Button("Open") { onAction(.open) }
                            .buttonStyle(SmallActionButtonStyle(color: .secondary))
                            .font(.system(size: 10))

                        Menu {
                            Button("View Pull Requests") { onAction(.viewPRs) }
                            Button("View Issues") { onAction(.viewIssues) }
                            Divider()
                            Button("Delete Repository", role: .destructive) { onAction(.delete) }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(width: 28, height: 24)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(5)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 28)
                    }
                }
            }
            .padding(14)
        }
        .background(
            isHovered
                ? Color.white.opacity(0.04)
                : Color.white.opacity(0.02)
        )
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isHovered ? Color(hex: "#00D4AA").opacity(0.2) : Color.white.opacity(0.06),
                    lineWidth: 1
                )
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Create Repo Sheet
struct CreateRepoSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var description_ = ""
    @State private var isPrivate = false
    @State private var initReadme = true
    @State private var linkLocalPath = false
    @State private var localPath = ""

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Create GitHub Repository", icon: "plus.circle.fill")

            ScrollView {
                VStack(spacing: 16) {
                    GTTextField(label: "Repository Name", text: $name, placeholder: "my-awesome-project")
                    GTTextField(label: "Description (optional)", text: $description_, placeholder: "What is this project about?")

                    Toggle("Private repository", isOn: $isPrivate)
                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#BF5AF2")))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Toggle("Initialize with README", isOn: $initReadme)
                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#00D4AA")))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Divider().opacity(0.2)

                    Toggle("Link to local folder", isOn: $linkLocalPath)
                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#5AC8FA")))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    if linkLocalPath {
                        HStack {
                            Text(localPath.isEmpty ? "No folder selected" : localPath)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(localPath.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button("Browse...") {
                                let panel = NSOpenPanel()
                                panel.canChooseDirectories = true
                                panel.canChooseFiles = false
                                if panel.runModal() == .OK, let url = panel.url {
                                    localPath = url.path
                                    if name.isEmpty {
                                        name = url.lastPathComponent
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                        }

                        Text("This will push the local repo to GitHub as the initial push.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(20)
            }

            SheetFooter(
                confirmLabel: "Create Repository",
                isEnabled: !name.isEmpty && name.range(of: #"^[a-zA-Z0-9_.-]+$"#, options: .regularExpression) != nil
            ) {
                isPresented = false
                Task {
                    await vm.createGitHubRepo(
                        name: name,
                        description: description_,
                        isPrivate: isPrivate,
                        initReadme: initReadme,
                        localPath: linkLocalPath && !localPath.isEmpty ? localPath : nil
                    )
                }
            } onCancel: {
                isPresented = false
            }
        }
        .frame(width: 460, height: 500)
        .background(Color(hex: "#161B22"))
    }
}
