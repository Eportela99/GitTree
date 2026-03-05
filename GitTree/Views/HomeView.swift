import SwiftUI

struct HomeView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Left: Branding + Quick Actions
            VStack(spacing: 0) {
                // Hero
                VStack(spacing: 16) {
                    Spacer()

                    Image("AppIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 96, height: 96)
                        .shadow(color: Color(hex: "#00D4AA").opacity(0.4), radius: 20)

                    Text("GitTree")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Visual Git & GitHub Manager")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .frame(maxWidth: .infinity)

                Divider().opacity(0.2)

                // Quick Actions
                VStack(spacing: 8) {
                    Text("QUICK ACTIONS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)

                    QuickActionButton(
                        icon: "folder.badge.plus",
                        title: "Open Repository",
                        subtitle: "Select a folder to open",
                        color: Color(hex: "#00D4AA")
                    ) {
                        vm.openFolderPicker()
                    }

                    QuickActionButton(
                        icon: "externaldrive.badge.plus",
                        title: "Initialize Repository",
                        subtitle: "Run git init in a folder",
                        color: Color(hex: "#5AC8FA")
                    ) {
                        vm.showInitRepoSheet = true
                    }

                    QuickActionButton(
                        icon: "network",
                        title: "GitHub",
                        subtitle: "Manage your GitHub repos",
                        color: Color(hex: "#BF5AF2")
                    ) {
                        vm.selectedTab = .github
                    }
                }
                .padding(20)
            }
            .frame(width: 260)
            .background(Color(hex: "#161B22"))

            Divider().opacity(0.2)

            // Right: Status + Recent Repos
            VStack(spacing: 0) {
                // GitHub Connection Status
                GitHubStatusCard()
                    .padding(20)

                Divider().opacity(0.15)

                // Recent Repos
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("RECENT REPOSITORIES")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        if !vm.recentRepos.isEmpty {
                            Button("Clear All") {
                                vm.recentRepos.removeAll()
                                UserDefaults.standard.removeObject(forKey: "recentRepos")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .buttonStyle(.plain)
                        }
                    }

                    if vm.recentRepos.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            Text("No recent repositories")
                                .font(.callout)
                                .foregroundColor(.secondary)
                            Text("Open a folder to get started")
                                .font(.caption)
                                .foregroundColor(Color.secondary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(vm.recentRepos) { repo in
                                    RecentRepoRow(repo: repo)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "#0D1117"))
        }
    }
}

// MARK: - GitHub Status Card
struct GitHubStatusCard: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var isTesting = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(vm.isGitHubAuthenticated
                          ? Color(hex: "#3DD68C").opacity(0.15)
                          : Color(hex: "#FF5A5A").opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "network")
                    .font(.system(size: 20))
                    .foregroundColor(vm.isGitHubAuthenticated
                                     ? Color(hex: "#3DD68C")
                                     : Color(hex: "#FF5A5A"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("GitHub Connection")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                if vm.isGitHubAuthenticated {
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: "#3DD68C")).frame(width: 6, height: 6)
                        Text("Connected as @\(vm.gitHubUsername ?? "unknown")")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#3DD68C"))
                    }
                    if let user = vm.gitHubUser {
                        Text("\(user.publicRepos) repos · \(user.followers) followers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: "#FF5A5A")).frame(width: 6, height: 6)
                        Text("Not connected")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#FF5A5A"))
                    }
                    Text("Run `gh auth login` to authenticate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                isTesting = true
                Task {
                    await vm.checkGitHubAuth()
                    isTesting = false
                }
            } label: {
                HStack(spacing: 6) {
                    if isTesting {
                        ProgressView().scaleEffect(0.7).frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                    Text("Test Connection")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(hex: "#00D4AA").opacity(0.15))
                .foregroundColor(Color(hex: "#00D4AA"))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#00D4AA").opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(isTesting)
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.12))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isHovered ? Color.white.opacity(0.06) : Color.white.opacity(0.03))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Recent Repo Row
struct RecentRepoRow: View {
    @EnvironmentObject var vm: AppViewModel
    let repo: RecentRepo
    @State private var isHovered = false

    private var exists: Bool {
        FileManager.default.fileExists(atPath: repo.path)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: exists ? "internaldrive.fill" : "questionmark.circle")
                .font(.system(size: 14))
                .foregroundColor(exists ? Color(hex: "#00D4AA") : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(repo.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(exists ? .white : .secondary)
                Text(repo.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Relative date
            Text(relativeDate(repo.lastOpened))
                .font(.caption2)
                .foregroundColor(Color.secondary.opacity(0.7))

            if isHovered {
                Button {
                    vm.removeFromRecentRepos(repo)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isHovered ? Color.white.opacity(0.05) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            if exists {
                Task { await vm.openRepository(at: repo.path) }
            }
        }
        .opacity(exists ? 1 : 0.5)
    }

    func relativeDate(_ date: Date) -> String {
        let secs = Int(Date().timeIntervalSince(date))
        if secs < 60 { return "just now" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        if secs < 86400 { return "\(secs / 3600)h ago" }
        return "\(secs / 86400)d ago"
    }
}
