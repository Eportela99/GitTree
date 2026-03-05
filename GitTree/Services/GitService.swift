import Foundation
import SwiftUI

@MainActor
class GitService: ObservableObject {
    private let runner = ProcessRunner.shared

    // MARK: - Repository Info
    /// Returns the current branch name, or "" when in detached HEAD state.
    func getCurrentBranch(at path: String) async -> String {
        // symbolic-ref fails in detached HEAD — that's expected, return ""
        if let out = try? await runner.git(["symbolic-ref", "--short", "HEAD"], in: path) {
            return out.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    /// Returns the short commit hash of the current HEAD (works in detached HEAD too).
    func getHEADHash(at path: String) async -> String {
        let out = (try? await runner.git(["rev-parse", "--short", "HEAD"], in: path)) ?? ""
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getRemoteURL(at path: String) async throws -> String {
        let out = try await runner.git(["remote", "get-url", "origin"], in: path)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func hasRemote(at path: String) async -> Bool {
        do {
            _ = try await runner.git(["remote"], in: path)
            let remotes = (try? await runner.git(["remote"], in: path)) ?? ""
            return !remotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return false
        }
    }

    func getAheadBehind(at path: String, branch: String) async -> (ahead: Int, behind: Int) {
        do {
            let out = try await runner.git(
                ["rev-list", "--left-right", "--count", "\(branch)...origin/\(branch)"],
                in: path
            )
            let parts = out.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
            if parts.count == 2 {
                return (Int(parts[0]) ?? 0, Int(parts[1]) ?? 0)
            }
        } catch {}
        return (0, 0)
    }

    // MARK: - Branches
    func getBranches(at path: String) async throws -> [Branch] {
        let format = "%(refname:short)|%(objectname:short)|%(subject)|%(upstream:short)|%(upstream:track)"
        let out = try await runner.git(
            ["for-each-ref", "--format=\(format)", "refs/heads/"],
            in: path
        )
        let currentBranch = await getCurrentBranch(at: path)
        var branches: [Branch] = []

        for line in out.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.components(separatedBy: "|")
            if parts.count >= 3 {
                let name = parts[0]
                let hash = parts[1]
                let msg = parts[2]
                let tracking = parts.count > 3 ? parts[3] : ""
                let trackInfo = parts.count > 4 ? parts[4] : ""

                var ahead = 0, behind = 0
                if !trackInfo.isEmpty {
                    let aheadMatch = trackInfo.range(of: #"ahead (\d+)"#, options: .regularExpression)
                    let behindMatch = trackInfo.range(of: #"behind (\d+)"#, options: .regularExpression)
                    if let r = aheadMatch {
                        ahead = Int(trackInfo[r].components(separatedBy: " ").last ?? "0") ?? 0
                    }
                    if let r = behindMatch {
                        behind = Int(trackInfo[r].components(separatedBy: " ").last ?? "0") ?? 0
                    }
                }

                branches.append(Branch(
                    name: name,
                    isCurrent: name == currentBranch,
                    isRemote: false,
                    trackingBranch: tracking.isEmpty ? nil : tracking,
                    aheadCount: ahead,
                    behindCount: behind,
                    lastCommitHash: hash,
                    lastCommitMessage: msg
                ))
            }
        }
        return branches.sorted { $0.isCurrent && !$1.isCurrent }
    }

    func getRemoteBranches(at path: String) async throws -> [Branch] {
        let out = try await runner.git(
            ["for-each-ref", "--format=%(refname:short)|%(objectname:short)|%(subject)", "refs/remotes/origin/"],
            in: path
        )
        var branches: [Branch] = []
        for line in out.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.components(separatedBy: "|")
            if parts.count >= 3 {
                let name = parts[0].replacingOccurrences(of: "origin/", with: "")
                if name == "HEAD" { continue }
                branches.append(Branch(
                    name: name,
                    isCurrent: false,
                    isRemote: true,
                    lastCommitHash: parts[1],
                    lastCommitMessage: parts[2]
                ))
            }
        }
        return branches
    }

    func createBranch(name: String, at path: String, checkout: Bool = true) async throws {
        if checkout {
            try await runner.git(["checkout", "-b", name], in: path)
        } else {
            try await runner.git(["branch", name], in: path)
        }
    }

    func checkoutBranch(_ name: String, at path: String, isRemote: Bool = false) async throws {
        if isRemote {
            try await runner.git(["checkout", "-b", name, "origin/\(name)"], in: path)
        } else {
            try await runner.git(["checkout", name], in: path)
        }
    }

    func deleteBranch(_ name: String, at path: String, force: Bool = false) async throws {
        try await runner.git(["branch", force ? "-D" : "-d", name], in: path)
    }

    func renameBranch(from oldName: String, to newName: String, at path: String) async throws {
        try await runner.git(["branch", "-m", oldName, newName], in: path)
    }

    /// Force-moves an existing branch pointer to the given ref (e.g. HEAD).
    func forceMoveBranch(name: String, to ref: String, at path: String) async throws {
        try await runner.git(["branch", "-f", name, ref], in: path)
    }

    func mergeBranch(_ name: String, at path: String) async throws {
        try await runner.git(["merge", name], in: path)
    }

    // MARK: - Commits
    func getCommits(at path: String, branch: String? = nil, limit: Int = 100) async throws -> [Commit] {
        var args = ["log",
                    "--pretty=format:%H|%P|%s|%an|%ae|%ad|%D",
                    "--date=format:%Y-%m-%d %H:%M",
                    "-\(limit)"]
        if let branch { args.append(branch) }

        let out = try await runner.git(args, in: path)
        var commits: [Commit] = []

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"

        for line in out.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 6 else { continue }

            let hash = parts[0]
            let parents = parts[1].split(separator: " ").map(String.init)
            let message = parts[2]
            let author = parts[3]
            let email = parts[4]
            let dateStr = parts[5]
            let refs = parts.count > 6 ? parts[6].components(separatedBy: ", ").filter { !$0.isEmpty } : []

            let date = df.date(from: dateStr) ?? Date()
            commits.append(Commit(
                hash: hash,
                message: message,
                author: author,
                email: email,
                date: date,
                dateFormatted: dateStr,
                parentHashes: parents,
                refs: refs.map { $0.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "HEAD -> ", with: "")
                    .replacingOccurrences(of: "tag: ", with: "")
                }
            ))
        }

        return applyGraphLayout(to: commits)
    }

    // MARK: - Graph Layout
    private func applyGraphLayout(to commits: [Commit]) -> [Commit] {
        var result = commits
        var columnMap: [String: Int] = [:]
        var nextColumn = 0

        for i in 0..<result.count {
            let hash = result[i].hash

            if columnMap[hash] == nil {
                columnMap[hash] = nextColumn
                nextColumn += 1
            }

            result[i].graphColumn = columnMap[hash]!

            for (idx, parentHash) in result[i].parentHashes.enumerated() {
                if columnMap[parentHash] == nil {
                    if idx == 0 {
                        columnMap[parentHash] = columnMap[hash]!
                    } else {
                        columnMap[parentHash] = nextColumn
                        nextColumn += 1
                    }
                }
            }
        }

        return result
    }

    func getCommitDetail(hash: String, at path: String) async throws -> String {
        try await runner.git(["show", "--stat", hash], in: path)
    }

    func getDiff(for file: String, staged: Bool, at path: String) async throws -> String {
        var args = ["diff"]
        if staged { args.append("--staged") }
        args.append("--")
        args.append(file)
        return try await runner.git(args, in: path)
    }

    func getDiffForCommit(hash: String, at path: String) async throws -> String {
        try await runner.git(["diff", "\(hash)^\(hash)"], in: path)
    }

    func checkoutCommit(hash: String, at path: String) async throws {
        try await runner.git(["checkout", hash], in: path)
    }

    func revertCommit(hash: String, at path: String) async throws {
        try await runner.git(["revert", "--no-edit", hash], in: path)
    }

    func resetToCommit(hash: String, mode: String, at path: String) async throws {
        try await runner.git(["reset", "--\(mode)", hash], in: path)
    }

    // MARK: - Working Tree
    func getStatus(at path: String) async throws -> [FileChange] {
        let out = try await runner.git(["status", "--porcelain=v1"], in: path)
        var changes: [FileChange] = []

        for line in out.components(separatedBy: "\n") where line.count >= 3 {
            let indexStatus = String(line.prefix(1))
            let workStatus = String(line.dropFirst().prefix(1))
            let filePath = String(line.dropFirst(3))

            if indexStatus != " " && indexStatus != "?" {
                let status = FileChange.FileStatus(rawValue: indexStatus) ?? .modified
                changes.append(FileChange(path: filePath, status: status, isStaged: true))
            }

            if workStatus != " " {
                let status = workStatus == "?" ? FileChange.FileStatus.untracked :
                    (FileChange.FileStatus(rawValue: workStatus) ?? .modified)
                changes.append(FileChange(path: filePath, status: status, isStaged: false))
            }
        }

        return changes
    }

    func stageFile(_ file: String, at path: String) async throws {
        try await runner.git(["add", file], in: path)
    }

    func stageAll(at path: String) async throws {
        try await runner.git(["add", "."], in: path)
    }

    func unstageFile(_ file: String, at path: String) async throws {
        try await runner.git(["restore", "--staged", file], in: path)
    }

    func discardChanges(in file: String, at path: String) async throws {
        try await runner.git(["restore", file], in: path)
    }

    func commit(message: String, at path: String) async throws {
        try await runner.git(["commit", "-m", message], in: path)
    }

    func amendCommit(message: String, at path: String) async throws {
        try await runner.git(["commit", "--amend", "-m", message], in: path)
    }

    // MARK: - Remote
    func fetch(at path: String) async throws {
        try await runner.git(["fetch", "--all", "--prune"], in: path)
    }

    func pull(at path: String, branch: String) async throws {
        try await runner.git(["pull", "origin", branch], in: path)
    }

    func push(at path: String, branch: String, setUpstream: Bool = false) async throws {
        var args = ["push", "origin", branch]
        if setUpstream { args.insert("-u", at: 1) }
        try await runner.git(args, in: path)
    }

    func addRemote(url: String, at path: String, name: String = "origin") async throws {
        try await runner.git(["remote", "add", name, url], in: path)
    }

    // MARK: - Stash
    func stashChanges(message: String? = nil, at path: String) async throws {
        var args = ["stash", "push"]
        if let msg = message { args += ["-m", msg] }
        try await runner.git(args, in: path)
    }

    func stashPop(index: Int = 0, at path: String) async throws {
        try await runner.git(["stash", "pop", "stash@{\(index)}"], in: path)
    }

    func stashDrop(index: Int, at path: String) async throws {
        try await runner.git(["stash", "drop", "stash@{\(index)}"], in: path)
    }

    func getStashList(at path: String) async throws -> [Stash] {
        let out = try await runner.git(["stash", "list", "--format=%gd|%s|%ci"], in: path)
        var stashes: [Stash] = []
        for (i, line) in out.components(separatedBy: "\n").enumerated() where !line.isEmpty {
            let parts = line.components(separatedBy: "|")
            let ref = parts.first ?? "stash@{\(i)}"
            let desc = parts.count > 1 ? parts[1] : line
            let date = parts.count > 2 ? String(parts[2].prefix(10)) : ""
            stashes.append(Stash(index: i, name: ref, description: desc, date: date))
        }
        return stashes
    }

    // MARK: - Init
    func initRepository(at path: String) async throws {
        try await runner.git(["init"], in: path)
    }

    func isGitRepo(at path: String) async -> Bool {
        await runner.isGitRepo(at: path)
    }
}
