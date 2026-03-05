import Foundation
import SwiftUI
import AppKit

@MainActor
class AppViewModel: ObservableObject {
    let git = GitService()
    let github = GitHubService()

    // MARK: - Navigation
    @Published var selectedTab: AppTab = .home
    @Published var showFolderPicker = false
    @Published var showInitRepoSheet = false

    // MARK: - Repository State
    @Published var currentRepo: Repository?
    @Published var branches: [Branch] = []
    @Published var remoteBranches: [Branch] = []
    @Published var commits: [Commit] = []
    @Published var changes: [FileChange] = []
    @Published var stashes: [Stash] = []
    @Published var selectedBranch: Branch?
    @Published var selectedCommit: Commit?
    @Published var commitDiff: String = ""
    @Published var selectedFile: FileChange?
    @Published var fileDiff: String = ""

    // MARK: - Recent Repos
    @Published var recentRepos: [RecentRepo] = []

    // MARK: - GitHub State
    @Published var isGitHubAuthenticated = false
    @Published var gitHubUsername: String? = nil
    @Published var gitHubUser: GitHubUser? = nil
    @Published var gitHubRepos: [GitHubRepo] = []
    @Published var selectedGitHubRepo: GitHubRepo?
    @Published var pullRequests: [PullRequest] = []
    @Published var issues: [GitHubIssue] = []
    @Published var gitHubSection: GitHubSection = .repositories

    // MARK: - Loading & Errors
    @Published var isLoading = false
    @Published var loadingMessage = ""
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""

    enum GitHubSection: String, CaseIterable {
        case repositories = "Repositories"
        case pullRequests = "Pull Requests"
        case issues = "Issues"
    }

    // MARK: - Init
    init() {
        loadRecentRepos()
        Task { await checkGitHubAuth() }
    }

    // MARK: - Admin Permission
    @Published var showAdminPrompt = false
    @Published var adminPromptCommand = ""
    @Published var adminPromptAction: (() async -> Void)?

    func runWithAdminIfNeeded(_ command: String, action: @escaping () async -> Void) {
        adminPromptCommand = command
        adminPromptAction = action
        showAdminPrompt = true
    }

    func executeWithAdminPrivileges(command: String) async {
        setLoading(true, message: "Running with administrator privileges...")
        defer { setLoading(false) }
        do {
            let result = try await ProcessRunner.shared.runWithAdminPrivileges(command: command)
            showSuccess("Command completed successfully")
            await refreshAll()
            _ = result
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - Error Handling
    func showError(_ message: String) {
        errorMessage = message
        successMessage = nil
        // If "Permission denied", offer to retry with admin
        if message.localizedCaseInsensitiveContains("permission denied") ||
           message.localizedCaseInsensitiveContains("Operation not permitted") {
            adminPromptCommand = "Retry this operation with administrator privileges?"
            showAdminPrompt = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.errorMessage = nil
        }
    }

    func showSuccess(_ message: String) {
        successMessage = message
        errorMessage = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.successMessage = nil
        }
    }

    func setLoading(_ loading: Bool, message: String = "") {
        isLoading = loading
        loadingMessage = message
    }

    // MARK: - Folder Picker
    func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Select a Git Repository"
        panel.prompt = "Open"

        if panel.runModal() == .OK, let url = panel.url {
            Task { await openRepository(at: url.path) }
        }
    }

    // MARK: - Repository Operations
    func openRepository(at path: String) async {
        setLoading(true, message: "Loading repository...")
        defer { setLoading(false) }

        let isGit = await git.isGitRepo(at: path)

        var repo = Repository(path: path)
        repo.isGitRepo = isGit

        if isGit {
            repo.currentBranch = await git.getCurrentBranch(at: path)
            repo.hasRemote = await git.hasRemote(at: path)
            if repo.hasRemote {
                repo.remoteURL = (try? await git.getRemoteURL(at: path)) ?? ""
            }
        }

        currentRepo = repo
        addToRecentRepos(path: path)

        if isGit {
            await refreshAll()
            selectedTab = .local
        } else {
            showError("'\(repo.name)' is not a git repository. You can initialize one.")
            selectedTab = .local
        }
    }

    func refreshAll() async {
        guard let repo = currentRepo else { return }
        // Always refresh currentBranch first — handles detached HEAD ("" when symbolic-ref fails)
        let branch = await git.getCurrentBranch(at: repo.path)
        currentRepo?.currentBranch = branch
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadBranches(for: repo) }
            group.addTask { await self.loadCommits(for: repo) }
            group.addTask { await self.loadChanges(for: repo) }
            group.addTask { await self.loadStashes(for: repo) }
        }
    }

    func loadBranches(for repo: Repository) async {
        do {
            branches = try await git.getBranches(at: repo.path)
            remoteBranches = try await git.getRemoteBranches(at: repo.path)
            selectedBranch = branches.first { $0.isCurrent }
        } catch {
            showError(error.localizedDescription)
        }
    }

    func loadCommits(for repo: Repository) async {
        do {
            commits = try await git.getCommits(at: repo.path, limit: 150)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func loadChanges(for repo: Repository) async {
        do {
            changes = try await git.getStatus(at: repo.path)
            currentRepo?.isDirty = !changes.isEmpty
        } catch {
            showError(error.localizedDescription)
        }
    }

    func loadStashes(for repo: Repository) async {
        do {
            stashes = try await git.getStashList(at: repo.path)
        } catch {
            stashes = []
        }
    }

    // MARK: - Branch Actions
    func checkoutBranch(_ branch: Branch) async {
        guard let repo = currentRepo else { return }
        setLoading(true, message: "Checking out \(branch.name)...")
        defer { setLoading(false) }
        do {
            try await git.checkoutBranch(branch.name, at: repo.path, isRemote: branch.isRemote)
            currentRepo?.currentBranch = branch.name
            await refreshAll()
            showSuccess("Switched to branch '\(branch.name)'")
        } catch {
            showError(error.localizedDescription)
        }
    }

    /// Force-moves an existing branch pointer to current HEAD (detached HEAD workflow).
    func moveBranchToHEAD(_ branchName: String, thenCheckout: Bool = true) async {
        guard let repo = currentRepo else { return }
        setLoading(true, message: "Moving '\(branchName)' to current commit...")
        defer { setLoading(false) }
        do {
            // git branch -f <name> HEAD  — repoints the branch to current commit
            try await git.forceMoveBranch(name: branchName, to: "HEAD", at: repo.path)
            if thenCheckout {
                try await git.checkoutBranch(branchName, at: repo.path)
                currentRepo?.currentBranch = branchName
            }
            await refreshAll()
            showSuccess("'\(branchName)' now points to this commit")
        } catch {
            showError(error.localizedDescription)
        }
    }

    func returnToBranch(_ name: String) async {
        guard let repo = currentRepo else { return }
        setLoading(true, message: "Returning to '\(name)'...")
        defer { setLoading(false) }
        do {
            try await git.checkoutBranch(name, at: repo.path)
            currentRepo?.currentBranch = name
            await refreshAll()
            showSuccess("Back on branch '\(name)'")
        } catch {
            showError(error.localizedDescription)
        }
    }

    var isDetachedHEAD: Bool {
        currentRepo?.currentBranch.isEmpty == true ||
        currentRepo?.currentBranch == "HEAD"
    }

    func createBranch(name: String, checkout: Bool = true) async {
        guard let repo = currentRepo else { return }
        setLoading(true, message: "Creating branch...")
        defer { setLoading(false) }
        do {
            try await git.createBranch(name: name, at: repo.path, checkout: checkout)
            await loadBranches(for: repo)
            if checkout {
                currentRepo?.currentBranch = name
                await loadCommits(for: repo)
            }
            showSuccess("Branch '\(name)' created")
        } catch {
            showError(error.localizedDescription)
        }
    }

    func deleteBranch(_ branch: Branch, force: Bool = false) async {
        guard let repo = currentRepo else { return }
        setLoading(true, message: "Deleting branch...")
        defer { setLoading(false) }
        do {
            try await git.deleteBranch(branch.name, at: repo.path, force: force)
            await loadBranches(for: repo)
            showSuccess("Branch '\(branch.name)' deleted")
        } catch {
            showError(error.localizedDescription)
        }
    }

    func renameBranch(_ branch: Branch, to newName: String) async {
        guard let repo = currentRepo else { return }
        do {
            try await git.renameBranch(from: branch.name, to: newName, at: repo.path)
            await loadBranches(for: repo)
            showSuccess("Branch renamed to '\(newName)'")
        } catch {
            showError(error.localizedDescription)
        }
    }

    func mergeBranch(_ branch: Branch) async {
        guard let repo = currentRepo else { return }
        setLoading(true, message: "Merging \(branch.name)...")
        defer { setLoading(false) }
        do {
            try await git.mergeBranch(branch.name, at: repo.path)
            await refreshAll()
            showSuccess("Merged '\(branch.name)'")
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - Commit Actions
    func selectCommit(_ commit: Commit) async {
        selectedCommit = commit
        guard let repo = currentRepo else { return }
        do {
            commitDiff = try await git.getDiffForCommit(hash: commit.hash, at: repo.path)
        } catch {
            commitDiff = ""
        }
    }

    func checkoutCommit(_ commit: Commit) async {
        guard let repo = currentRepo else { return }
        setLoading(true, message: "Checking out commit...")
        defer { setLoading(false) }
        do {
            try await git.checkoutCommit(hash: commit.hash, at: repo.path)
            await refreshAll()
            showSuccess("Detached HEAD at \(commit.shortHash)")
        } catch {
            showError(error.localizedDescription)
        }
    }

    func revertCommit(_ commit: Commit) async {
        guard let repo = currentRepo else { return }
        setLoading(true, message: "Reverting commit...")
        defer { setLoading(false) }
        do {
            try await git.revertCommit(hash: commit.hash, at: repo.path)
            await refreshAll()
            showSuccess("Reverted commit \(commit.shortHash)")
        } catch {
            showError(error.localizedDescription)
        }
    }

    func resetToCommit(_ commit: Commit, mode: String) async {
        guard let repo = currentRepo else { return }
        setLoading(true, message: "Resetting...")
        defer { setLoading(false) }
        do {
            try await git.resetToCommit(hash: commit.hash, mode: mode, at: repo.path)
            await refreshAll()
            showSuccess("Reset to \(commit.shortHash)")
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - Staging & Commit
    func stageFile(_ file: FileChange) async {
        guard let repo = currentRepo else { return }
        do {
            try await git.stageFile(file.path, at: repo.path)
            await loadChanges(for: repo)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func stageAll() async {
        guard let repo = currentRepo else { return }
        do {
            try await git.stageAll(at: repo.path)
            await loadChanges(for: repo)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func unstageFile(_ file: FileChange) async {
        guard let repo = currentRepo else { return }
        do {
            try await git.unstageFile(file.path, at: repo.path)
            await loadChanges(for: repo)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func discardChanges(in file: FileChange) async {
        guard let repo = currentRepo else { return }
        do {
            try await git.discardChanges(in: file.path, at: repo.path)
            await loadChanges(for: repo)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func loadFileDiff(for file: FileChange) async {
        guard let repo = currentRepo else { return }
        do {
            fileDiff = try await git.getDiff(for: file.path, staged: file.isStaged, at: repo.path)
            selectedFile = file
        } catch {
            fileDiff = ""
        }
    }

    func makeCommit(message: String) async {
        guard let repo = currentRepo else { return }
        setLoading(true, message: "Committing...")
        defer { setLoading(false) }
        do {
            try await git.commit(message: message, at: repo.path)
            await refreshAll()
            showSuccess("Committed successfully")
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - Remote Actions
    func fetch() async {
        guard let repo = currentRepo else { return }
        setLoading(true, message: "Fetching...")
        defer { setLoading(false) }
        do {
            try await git.fetch(at: repo.path)
            await refreshAll()
            showSuccess("Fetched from remote")
        } catch {
            showError(error.localizedDescription)
        }
    }

    func pull() async {
        guard let repo = currentRepo, !repo.currentBranch.isEmpty else { return }
        setLoading(true, message: "Pulling...")
        defer { setLoading(false) }
        do {
            try await git.pull(at: repo.path, branch: repo.currentBranch)
            await refreshAll()
            showSuccess("Pulled from origin/\(repo.currentBranch)")
        } catch {
            showError(error.localizedDescription)
        }
    }

    func push(setUpstream: Bool = false) async {
        guard let repo = currentRepo, !repo.currentBranch.isEmpty, repo.currentBranch != "HEAD" else {
            showError("You are in detached HEAD state. Create a branch first before pushing.")
            return
        }
        setLoading(true, message: "Pushing \(repo.currentBranch)...")
        defer { setLoading(false) }

        // Check if this branch has a remote tracking branch; if not, set upstream automatically
        let currentBranchInfo = branches.first { $0.isCurrent }
        let needsUpstream = setUpstream || (currentBranchInfo?.trackingBranch == nil)

        do {
            try await git.push(at: repo.path, branch: repo.currentBranch, setUpstream: needsUpstream)
            await refreshAll()
            if needsUpstream {
                showSuccess("Pushed and set upstream: origin/\(repo.currentBranch)")
            } else {
                showSuccess("Pushed to origin/\(repo.currentBranch)")
            }
        } catch {
            // If push fails because no upstream, retry with -u
            let errMsg = error.localizedDescription
            if errMsg.contains("no upstream") || errMsg.contains("set-upstream") || errMsg.contains("--set-upstream") {
                do {
                    try await git.push(at: repo.path, branch: repo.currentBranch, setUpstream: true)
                    await refreshAll()
                    showSuccess("Pushed and set upstream: origin/\(repo.currentBranch)")
                } catch {
                    showError(error.localizedDescription)
                }
            } else {
                showError(errMsg)
            }
        }
    }

    // MARK: - Stash Actions
    func stashChanges(message: String? = nil) async {
        guard let repo = currentRepo else { return }
        do {
            try await git.stashChanges(message: message, at: repo.path)
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadChanges(for: repo) }
                group.addTask { await self.loadStashes(for: repo) }
            }
            showSuccess("Changes stashed")
        } catch {
            showError(error.localizedDescription)
        }
    }

    func popStash(_ stash: Stash) async {
        guard let repo = currentRepo else { return }
        do {
            try await git.stashPop(index: stash.index, at: repo.path)
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadChanges(for: repo) }
                group.addTask { await self.loadStashes(for: repo) }
            }
            showSuccess("Stash applied")
        } catch {
            showError(error.localizedDescription)
        }
    }

    func dropStash(_ stash: Stash) async {
        guard let repo = currentRepo else { return }
        do {
            try await git.stashDrop(index: stash.index, at: repo.path)
            await loadStashes(for: repo)
            showSuccess("Stash dropped")
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - Init Repo
    func initRepository(at path: String) async {
        setLoading(true, message: "Initializing repository...")
        defer { setLoading(false) }
        do {
            try await git.initRepository(at: path)
            await openRepository(at: path)
            showSuccess("Repository initialized")
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - GitHub Actions
    func checkGitHubAuth() async {
        let (auth, username) = await github.checkAuthStatus()
        isGitHubAuthenticated = auth
        gitHubUsername = username
        if auth {
            gitHubUser = try? await github.getCurrentUser()
        }
    }

    func loadGitHubRepos() async {
        guard isGitHubAuthenticated else { return }
        setLoading(true, message: "Loading repositories...")
        defer { setLoading(false) }
        do {
            gitHubRepos = try await github.listRepos()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func loadPullRequests(for repo: GitHubRepo) async {
        setLoading(true, message: "Loading pull requests...")
        defer { setLoading(false) }
        do {
            pullRequests = try await github.listPullRequests(repo: repo.fullName)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func loadIssues(for repo: GitHubRepo) async {
        setLoading(true, message: "Loading issues...")
        defer { setLoading(false) }
        do {
            issues = try await github.listIssues(repo: repo.fullName)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func createGitHubRepo(name: String, description: String, isPrivate: Bool,
                           initReadme: Bool, localPath: String?) async {
        setLoading(true, message: "Creating repository...")
        defer { setLoading(false) }
        do {
            try await github.createRepo(name: name, description: description,
                                        isPrivate: isPrivate, initReadme: initReadme,
                                        localPath: localPath)
            await loadGitHubRepos()
            showSuccess("Repository '\(name)' created on GitHub")
        } catch {
            showError(error.localizedDescription)
        }
    }

    func deleteGitHubRepo(_ repo: GitHubRepo) async {
        setLoading(true, message: "Deleting repository...")
        defer { setLoading(false) }
        do {
            try await github.deleteRepo(fullName: repo.fullName)
            gitHubRepos.removeAll { $0.id == repo.id }
            showSuccess("Repository '\(repo.name)' deleted")
        } catch {
            showError(error.localizedDescription)
        }
    }

    func cloneGitHubRepo(_ repo: GitHubRepo) async {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.title = "Choose Clone Location"
        panel.prompt = "Clone Here"

        if panel.runModal() == .OK, let url = panel.url {
            setLoading(true, message: "Cloning \(repo.name)...")
            defer { setLoading(false) }
            do {
                let dest = url.appendingPathComponent(repo.name).path
                try await github.cloneRepo(fullName: repo.fullName, toPath: dest)
                await openRepository(at: dest)
                showSuccess("Cloned '\(repo.name)'")
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    // MARK: - Recent Repos
    private func loadRecentRepos() {
        if let data = UserDefaults.standard.data(forKey: "recentRepos"),
           let repos = try? JSONDecoder().decode([RecentRepo].self, from: data) {
            recentRepos = repos.sorted { $0.lastOpened > $1.lastOpened }
        }
    }

    func addToRecentRepos(path: String) {
        let name = URL(fileURLWithPath: path).lastPathComponent
        recentRepos.removeAll { $0.path == path }
        recentRepos.insert(RecentRepo(path: path, name: name, lastOpened: Date()), at: 0)
        recentRepos = Array(recentRepos.prefix(10))
        if let data = try? JSONEncoder().encode(recentRepos) {
            UserDefaults.standard.set(data, forKey: "recentRepos")
        }
    }

    func removeFromRecentRepos(_ repo: RecentRepo) {
        recentRepos.removeAll { $0.id == repo.id }
        if let data = try? JSONEncoder().encode(recentRepos) {
            UserDefaults.standard.set(data, forKey: "recentRepos")
        }
    }
}
