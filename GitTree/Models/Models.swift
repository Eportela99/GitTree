import Foundation
import SwiftUI

// MARK: - App Error
enum AppError: LocalizedError {
    case commandFailed(String)
    case notAGitRepo
    case noRemote
    case ghNotFound
    case parseError(String)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .commandFailed(let msg): return msg
        case .notAGitRepo: return "Selected folder is not a git repository."
        case .noRemote: return "No remote repository configured."
        case .ghNotFound: return "GitHub CLI (gh) not found. Install it with: brew install gh"
        case .parseError(let msg): return "Parse error: \(msg)"
        case .notAuthenticated: return "Not authenticated with GitHub. Run: gh auth login"
        }
    }
}

// MARK: - App Tab
enum AppTab: String, CaseIterable {
    case home = "Home"
    case local = "Local"
    case github = "GitHub"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .local: return "internaldrive.fill"
        case .github: return "network"
        }
    }
}

// MARK: - Git Models
struct Repository: Identifiable, Hashable {
    let id = UUID()
    var path: String
    var name: String { URL(fileURLWithPath: path).lastPathComponent }
    var currentBranch: String = ""
    var hasRemote: Bool = false
    var remoteURL: String = ""
    var aheadCount: Int = 0
    var behindCount: Int = 0
    var isDirty: Bool = false
    var isGitRepo: Bool = false
}

struct Branch: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var isCurrent: Bool = false
    var isRemote: Bool = false
    var trackingBranch: String? = nil
    var aheadCount: Int = 0
    var behindCount: Int = 0
    var lastCommitHash: String = ""
    var lastCommitMessage: String = ""
}

struct Commit: Identifiable, Hashable {
    let id = UUID()
    var hash: String
    var shortHash: String { String(hash.prefix(7)) }
    var message: String
    var author: String
    var email: String
    var date: Date
    var dateFormatted: String
    var parentHashes: [String]
    var refs: [String]
    // Graph layout
    var graphColumn: Int = 0
    var graphLines: [GraphLine] = []
}

struct GraphLine: Hashable {
    enum LineType { case vertical, mergeIn, branchOut, continuation }
    var column: Int
    var type: LineType
    var color: Color
}

struct FileChange: Identifiable, Hashable {
    let id = UUID()
    var path: String
    var filename: String { URL(fileURLWithPath: path).lastPathComponent }
    var status: FileStatus
    var isStaged: Bool

    enum FileStatus: String {
        case added = "A"
        case modified = "M"
        case deleted = "D"
        case renamed = "R"
        case untracked = "?"
        case conflict = "U"
        case copied = "C"

        var label: String {
            switch self {
            case .added: return "Added"
            case .modified: return "Modified"
            case .deleted: return "Deleted"
            case .renamed: return "Renamed"
            case .untracked: return "Untracked"
            case .conflict: return "Conflict"
            case .copied: return "Copied"
            }
        }

        var icon: String {
            switch self {
            case .added: return "plus.circle.fill"
            case .modified: return "pencil.circle.fill"
            case .deleted: return "minus.circle.fill"
            case .renamed: return "arrow.left.arrow.right.circle.fill"
            case .untracked: return "questionmark.circle.fill"
            case .conflict: return "exclamationmark.triangle.fill"
            case .copied: return "doc.on.doc.fill"
            }
        }

        var color: Color {
            switch self {
            case .added: return Color(hex: "#3DD68C")
            case .modified: return Color(hex: "#F5A623")
            case .deleted: return Color(hex: "#FF5A5A")
            case .renamed: return Color(hex: "#5AC8FA")
            case .untracked: return .secondary
            case .conflict: return Color(hex: "#FF5A5A")
            case .copied: return Color(hex: "#5AC8FA")
            }
        }
    }
}

struct Stash: Identifiable, Hashable {
    let id = UUID()
    var index: Int
    var name: String
    var description: String
    var date: String
}

// MARK: - GitHub Models
struct GitHubRepo: Identifiable, Hashable {
    let id: String
    var name: String
    var fullName: String
    var description: String?
    var isPrivate: Bool
    var isForked: Bool
    var language: String?
    var stars: Int
    var forks: Int
    var defaultBranch: String
    var updatedAt: String
    var htmlURL: String
    var cloneURL: String
    var sshURL: String

    var languageColor: Color {
        switch language?.lowercased() {
        case "swift": return Color(hex: "#F05138")
        case "python": return Color(hex: "#3776AB")
        case "javascript", "typescript": return Color(hex: "#F7DF1E")
        case "go": return Color(hex: "#00ADD8")
        case "rust": return Color(hex: "#DEA584")
        case "kotlin": return Color(hex: "#7F52FF")
        case "java": return Color(hex: "#ED8B00")
        case "c", "c++": return Color(hex: "#555555")
        case "ruby": return Color(hex: "#CC342D")
        case "shell": return Color(hex: "#89E051")
        default: return .secondary
        }
    }
}

struct PullRequest: Identifiable, Hashable {
    let id: String
    var number: Int
    var title: String
    var state: String
    var author: String
    var body: String?
    var baseBranch: String
    var headBranch: String
    var createdAt: String
    var url: String
    var isDraft: Bool
    var reviewDecision: String?
}

struct GitHubIssue: Identifiable, Hashable {
    let id: String
    var number: Int
    var title: String
    var state: String
    var author: String
    var body: String?
    var labels: [String]
    var createdAt: String
    var url: String
}

struct GitHubUser: Hashable {
    var login: String
    var name: String?
    var email: String?
    var publicRepos: Int = 0
    var followers: Int = 0
    var following: Int = 0
    var bio: String?
}

// MARK: - Recent Repos
struct RecentRepo: Identifiable, Codable {
    var id: UUID = UUID()
    var path: String
    var name: String
    var lastOpened: Date
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Branch Colors
let branchColors: [Color] = [
    Color(hex: "#00D4AA"),
    Color(hex: "#5AC8FA"),
    Color(hex: "#BF5AF2"),
    Color(hex: "#FF9F0A"),
    Color(hex: "#FF375F"),
    Color(hex: "#30D158"),
    Color(hex: "#FFD60A"),
    Color(hex: "#FF6961"),
]

func branchColor(for index: Int) -> Color {
    branchColors[index % branchColors.count]
}
