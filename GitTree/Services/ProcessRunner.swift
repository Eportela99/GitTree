import Foundation

actor ProcessRunner {
    static let shared = ProcessRunner()

    private let gitPath: String
    private let ghPath: String?

    init() {
        // Resolve git path
        if FileManager.default.fileExists(atPath: "/usr/bin/git") {
            gitPath = "/usr/bin/git"
        } else {
            gitPath = "/opt/homebrew/bin/git"
        }

        // Resolve gh path
        let ghCandidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        ghPath = ghCandidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    func run(_ executablePath: String, arguments: [String], workingDirectory: String? = nil) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        if let dir = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: dir)
        }

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["GIT_TERMINAL_PROMPT"] = "0"
        process.environment = env

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let outStr = output.trimmingCharacters(in: .whitespacesAndNewlines)
            throw AppError.commandFailed(errStr.isEmpty ? outStr : errStr)
        }

        return output
    }

    func git(_ arguments: [String], in directory: String) async throws -> String {
        try await run(gitPath, arguments: arguments, workingDirectory: directory)
    }

    func gh(_ arguments: [String], in directory: String? = nil) async throws -> String {
        guard let ghPath else {
            throw AppError.ghNotFound
        }
        return try await run(ghPath, arguments: arguments, workingDirectory: directory)
    }

    func isGitRepo(at path: String) async -> Bool {
        do {
            _ = try await git(["rev-parse", "--git-dir"], in: path)
            return true
        } catch {
            return false
        }
    }

    func runWithAdminPrivileges(command: String) async throws -> String {
        let escapedCmd = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escapedCmd)\" with administrator privileges"
        return try await run("/usr/bin/osascript", arguments: ["-e", script])
    }
}
