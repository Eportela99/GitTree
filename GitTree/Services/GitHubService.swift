import Foundation
import SwiftUI

@MainActor
class GitHubService: ObservableObject {
    private let runner = ProcessRunner.shared

    // MARK: - Auth
    func checkAuthStatus() async -> (isAuthenticated: Bool, username: String?) {
        do {
            let out = try await runner.gh(["auth", "status"])
            let lines = out.components(separatedBy: "\n")
            for line in lines {
                // New format: "✓ Logged in to github.com account USERNAME (keyring)"
                // Old format: "Logged in to github.com as USERNAME"
                if line.contains("Logged in to github.com") {
                    // Try "account " format first
                    if let range = line.range(of: "account ") {
                        var user = String(line[range.upperBound...])
                            .components(separatedBy: " ").first ?? ""
                        user = user.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !user.isEmpty { return (true, user) }
                    }
                    // Fall back to "as " format
                    if let range = line.range(of: " as ") {
                        var user = String(line[range.upperBound...])
                            .components(separatedBy: " ").first ?? ""
                        user = user.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !user.isEmpty { return (true, user) }
                    }
                    return (true, nil)
                }
            }
        } catch {}
        return (false, nil)
    }

    func getCurrentUser() async throws -> GitHubUser {
        let out = try await runner.gh(["api", "user", "--jq",
            "[.login, .name // \"\", .email // \"\", (.public_repos | tostring), (.followers | tostring), (.following | tostring), .bio // \"\"] | join(\"|\")"])
        let parts = out.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "|")
        return GitHubUser(
            login: parts[safe: 0] ?? "",
            name: parts[safe: 1],
            email: parts[safe: 2],
            publicRepos: Int(parts[safe: 3] ?? "0") ?? 0,
            followers: Int(parts[safe: 4] ?? "0") ?? 0,
            following: Int(parts[safe: 5] ?? "0") ?? 0,
            bio: parts[safe: 6]
        )
    }

    func login() async throws {
        try await runner.gh(["auth", "login", "--web"])
    }

    func logout() async throws {
        try await runner.gh(["auth", "logout", "--hostname", "github.com", "--yes"])
    }

    // MARK: - Repositories
    func listRepos(limit: Int = 50) async throws -> [GitHubRepo] {
        let jq = "[.[] | {id: .id, name: .name, fullName: .nameWithOwner, description: (.description // \"\"), private: .isPrivate, fork: .isFork, language: (.primaryLanguage.name // \"\"), stars: .stargazerCount, forks: .forkCount, defaultBranch: .defaultBranchRef.name, updatedAt: .updatedAt, url: .url, cloneUrl: .url, sshUrl: .sshUrl}]"
        let out = try await runner.gh(["repo", "list", "--limit", "\(limit)",
            "--json", "id,name,nameWithOwner,description,isPrivate,isFork,primaryLanguage,stargazerCount,forkCount,defaultBranchRef,updatedAt,url,sshUrl"])
        return parseRepos(from: out)
    }

    func searchRepos(query: String) async throws -> [GitHubRepo] {
        let out = try await runner.gh(["search", "repos", query, "--limit", "20",
            "--json", "id,name,nameWithOwner,description,isPrivate,isFork,primaryLanguage,stargazerCount,forkCount,defaultBranchRef,updatedAt,url,sshUrl"])
        return parseRepos(from: out)
    }

    private func parseRepos(from json: String) -> [GitHubRepo] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return arr.compactMap { dict -> GitHubRepo? in
            guard let name = dict["name"] as? String else { return nil }

            // GitHub GraphQL IDs are strings (e.g. "R_kgDORXvXbA")
            let id: String
            if let strId = dict["id"] as? String { id = strId }
            else if let intId = dict["id"] as? Int { id = String(intId) }
            else { id = name } // fallback to name as unique key

            let lang = (dict["language"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let desc = (dict["description"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let htmlURL = dict["url"] as? String ?? ""
            let sshURL = dict["sshUrl"] as? String ?? ""
            let cloneURL = htmlURL.isEmpty ? "" : htmlURL + ".git"
            let updatedAt = (dict["updatedAt"] as? String ?? "").prefix(10).description

            return GitHubRepo(
                id: id,
                name: name,
                fullName: dict["fullName"] as? String ?? name,
                description: desc,
                isPrivate: dict["private"] as? Bool ?? false,
                isForked: dict["fork"] as? Bool ?? false,
                language: lang,
                stars: dict["stars"] as? Int ?? 0,
                forks: dict["forks"] as? Int ?? 0,
                defaultBranch: dict["defaultBranch"] as? String ?? "main",
                updatedAt: updatedAt,
                htmlURL: htmlURL,
                cloneURL: cloneURL,
                sshURL: sshURL
            )
        }
    }

    func createRepo(name: String, description: String, isPrivate: Bool,
                    initReadme: Bool, localPath: String? = nil) async throws {
        var args = ["repo", "create", name]
        args += isPrivate ? ["--private"] : ["--public"]
        if !description.isEmpty { args += ["--description", description] }
        if initReadme { args += ["--add-readme"] }
        if let path = localPath {
            args += ["--source", path, "--remote", "origin", "--push"]
        }
        try await runner.gh(args)
    }

    func deleteRepo(fullName: String) async throws {
        try await runner.gh(["repo", "delete", fullName, "--yes"])
    }

    func cloneRepo(fullName: String, toPath: String) async throws {
        try await runner.gh(["repo", "clone", fullName, toPath])
    }

    func openInBrowser(fullName: String) async throws {
        try await runner.gh(["repo", "view", fullName, "--web"])
    }

    // MARK: - Pull Requests
    func listPullRequests(repo: String) async throws -> [PullRequest] {
        let out = try await runner.gh(["pr", "list", "--repo", repo, "--limit", "30",
            "--json", "id,number,title,state,author,body,baseRefName,headRefName,createdAt,url,isDraft,reviewDecision"])

        guard let data = out.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return arr.compactMap { dict -> PullRequest? in
            guard let number = dict["number"] as? Int,
                  let title = dict["title"] as? String else { return nil }

            let id = (dict["id"] as? String) ?? String(number)
            let author = (dict["author"] as? [String: Any])?["login"] as? String ?? ""
            return PullRequest(
                id: id,
                number: number,
                title: title,
                state: dict["state"] as? String ?? "",
                author: author,
                body: dict["body"] as? String,
                baseBranch: dict["baseRefName"] as? String ?? "",
                headBranch: dict["headRefName"] as? String ?? "",
                createdAt: String((dict["createdAt"] as? String ?? "").prefix(10)),
                url: dict["url"] as? String ?? "",
                isDraft: dict["isDraft"] as? Bool ?? false,
                reviewDecision: dict["reviewDecision"] as? String
            )
        }
    }

    func createPR(title: String, body: String, base: String, head: String, repo: String) async throws {
        try await runner.gh(["pr", "create", "--repo", repo,
            "--title", title, "--body", body, "--base", base, "--head", head])
    }

    func mergePR(number: Int, repo: String) async throws {
        try await runner.gh(["pr", "merge", "\(number)", "--repo", repo, "--merge"])
    }

    func closePR(number: Int, repo: String) async throws {
        try await runner.gh(["pr", "close", "\(number)", "--repo", repo])
    }

    func openPRInBrowser(number: Int, repo: String) async throws {
        try await runner.gh(["pr", "view", "\(number)", "--repo", repo, "--web"])
    }

    // MARK: - Issues
    func listIssues(repo: String) async throws -> [GitHubIssue] {
        let out = try await runner.gh(["issue", "list", "--repo", repo, "--limit", "30",
            "--json", "id,number,title,state,author,body,labels,createdAt,url"])

        guard let data = out.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return arr.compactMap { dict -> GitHubIssue? in
            guard let number = dict["number"] as? Int,
                  let title = dict["title"] as? String else { return nil }

            let id = (dict["id"] as? String) ?? String(number)
            let author = (dict["author"] as? [String: Any])?["login"] as? String ?? ""
            let labels = (dict["labels"] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []
            return GitHubIssue(
                id: id,
                number: number,
                title: title,
                state: dict["state"] as? String ?? "",
                author: author,
                body: dict["body"] as? String,
                labels: labels,
                createdAt: String((dict["createdAt"] as? String ?? "").prefix(10)),
                url: dict["url"] as? String ?? ""
            )
        }
    }

    func createIssue(title: String, body: String, repo: String) async throws {
        try await runner.gh(["issue", "create", "--repo", repo,
            "--title", title, "--body", body])
    }

    func closeIssue(number: Int, repo: String) async throws {
        try await runner.gh(["issue", "close", "\(number)", "--repo", repo])
    }
}

// MARK: - Array Safe Subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
