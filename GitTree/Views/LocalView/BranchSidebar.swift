import SwiftUI

struct BranchSidebar: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var showNewBranchSheet: Bool
    @State private var searchText = ""
    @State private var expandRemotes = false
    @State private var renamingBranch: Branch?
    @State private var renameText = ""

    private var localBranches: [Branch] {
        if searchText.isEmpty { return vm.branches }
        return vm.branches.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var remoteBranches: [Branch] {
        if searchText.isEmpty { return vm.remoteBranches }
        return vm.remoteBranches.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#00D4AA"))
                Text("BRANCHES")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    showNewBranchSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#00D4AA"))
                }
                .buttonStyle(.plain)
                .help("New Branch")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(hex: "#161B22"))
            .overlay(Divider().opacity(0.2), alignment: .bottom)

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Filter branches...", text: $searchText)
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
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.04))
            .overlay(Divider().opacity(0.15), alignment: .bottom)

            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    // Local Branches
                    Section {
                        ForEach(localBranches) { branch in
                            BranchRow(
                                branch: branch,
                                isRenaming: renamingBranch?.id == branch.id,
                                renameText: $renameText
                            ) { action in
                                handleBranchAction(action, branch: branch)
                            }
                        }
                    } header: {
                        SectionHeader(title: "LOCAL", count: localBranches.count)
                    }

                    // Remote Branches
                    if !remoteBranches.isEmpty {
                        Section {
                            if expandRemotes {
                                ForEach(remoteBranches) { branch in
                                    BranchRow(branch: branch, isRenaming: false, renameText: .constant("")) { action in
                                        handleBranchAction(action, branch: branch)
                                    }
                                }
                            }
                        } header: {
                            Button {
                                expandRemotes.toggle()
                            } label: {
                                SectionHeader(
                                    title: "REMOTE",
                                    count: remoteBranches.count,
                                    chevron: expandRemotes ? "chevron.down" : "chevron.right"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .background(Color(hex: "#161B22"))
        .overlay(Divider().opacity(0.2), alignment: .trailing)
    }

    private func handleBranchAction(_ action: BranchRow.Action, branch: Branch) {
        switch action {
        case .checkout:
            Task { await vm.checkoutBranch(branch) }
        case .merge:
            Task { await vm.mergeBranch(branch) }
        case .delete:
            Task { await vm.deleteBranch(branch) }
        case .forceDelete:
            Task { await vm.deleteBranch(branch, force: true) }
        case .startRename:
            renamingBranch = branch
            renameText = branch.name
        case .commitRename:
            guard let b = renamingBranch, !renameText.isEmpty, renameText != b.name else {
                renamingBranch = nil
                return
            }
            Task {
                await vm.renameBranch(b, to: renameText)
                renamingBranch = nil
            }
        case .cancelRename:
            renamingBranch = nil
        case .push:
            Task { await vm.push() }
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let count: Int
    var chevron: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            Text("\(count)")
                .font(.system(size: 9))
                .foregroundColor(Color.secondary.opacity(0.7))
            Spacer()
            if let chevron {
                Image(systemName: chevron)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color(hex: "#161B22").opacity(0.95))
    }
}

// MARK: - Branch Row
struct BranchRow: View {
    @EnvironmentObject var vm: AppViewModel
    let branch: Branch
    let isRenaming: Bool
    @Binding var renameText: String
    let onAction: (Action) -> Void

    @State private var isHovered = false

    enum Action {
        case checkout, merge, delete, forceDelete
        case startRename, commitRename, cancelRename
        case push
    }

    var body: some View {
        HStack(spacing: 6) {
            // Current indicator dot
            Circle()
                .fill(branch.isCurrent ? Color(hex: "#00D4AA") : Color.clear)
                .frame(width: 6, height: 6)

            // Branch icon
            Image(systemName: branch.isRemote ? "cloud.fill" : "arrow.triangle.branch")
                .font(.system(size: 10))
                .foregroundColor(branch.isCurrent ? Color(hex: "#00D4AA") : .secondary)

            if isRenaming {
                TextField("", text: $renameText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit { onAction(.commitRename) }
                    .onExitCommand { onAction(.cancelRename) }
            } else {
                Text(branch.name)
                    .font(.system(size: 12, weight: branch.isCurrent ? .semibold : .regular))
                    .foregroundColor(branch.isCurrent ? .white : Color.secondary.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer()

            // Ahead/behind badges
            if branch.aheadCount > 0 || branch.behindCount > 0 {
                HStack(spacing: 2) {
                    if branch.aheadCount > 0 {
                        HStack(spacing: 1) {
                            Image(systemName: "arrow.up").font(.system(size: 8))
                            Text("\(branch.aheadCount)").font(.system(size: 9))
                        }
                        .foregroundColor(Color(hex: "#5AC8FA"))
                    }
                    if branch.behindCount > 0 {
                        HStack(spacing: 1) {
                            Image(systemName: "arrow.down").font(.system(size: 8))
                            Text("\(branch.behindCount)").font(.system(size: 9))
                        }
                        .foregroundColor(Color(hex: "#F5A623"))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            isHovered && !branch.isCurrent
                ? Color.white.opacity(0.05)
                : branch.isCurrent
                    ? Color(hex: "#00D4AA").opacity(0.08)
                    : Color.clear
        )
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture {
            if !branch.isCurrent && !isRenaming {
                onAction(.checkout)
            }
        }
        .contextMenu {
            branchContextMenu
        }
    }

    @ViewBuilder
    private var branchContextMenu: some View {
        if !branch.isCurrent && !branch.isRemote {
            Button("Checkout '\(branch.name)'") { onAction(.checkout) }
        }
        if !branch.isRemote {
            Button("Merge into Current Branch") { onAction(.merge) }
            Divider()
            Button("Push Branch") { onAction(.push) }
            Button("Rename Branch") { onAction(.startRename) }
            Divider()
            Button("Delete Branch", role: .destructive) { onAction(.delete) }
            Button("Force Delete Branch", role: .destructive) { onAction(.forceDelete) }
        } else {
            Button("Checkout as Local Branch") { onAction(.checkout) }
        }
    }
}
