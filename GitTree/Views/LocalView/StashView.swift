import SwiftUI

struct StashView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showStashMessage = false
    @State private var stashMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header Actions
            HStack(spacing: 8) {
                Button {
                    showStashMessage = true
                } label: {
                    Label("New Stash", systemImage: "tray.and.arrow.down.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(SmallActionButtonStyle(color: Color(hex: "#00D4AA"), filled: true))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "#161B22"))
            .overlay(Divider().opacity(0.2), alignment: .bottom)

            if vm.stashes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No stashes")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text("Stash changes to save them temporarily")
                        .font(.caption)
                        .foregroundColor(Color.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#0D1117"))
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(vm.stashes) { stash in
                            StashRow(stash: stash)
                        }
                    }
                    .padding(8)
                }
                .background(Color(hex: "#0D1117"))
            }
        }
        .sheet(isPresented: $showStashMessage) {
            QuickStashSheet(isPresented: $showStashMessage)
        }
    }
}

// MARK: - Stash Row
struct StashRow: View {
    @EnvironmentObject var vm: AppViewModel
    let stash: Stash
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "#5AC8FA").opacity(0.1))
                    .frame(width: 36, height: 36)
                Text("stash@{\(stash.index)}")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#5AC8FA"))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(2)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(stash.description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(stash.name)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                    if !stash.date.isEmpty {
                        Text("·")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(stash.date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if isHovered {
                HStack(spacing: 4) {
                    Button("Apply") {
                        Task { await vm.popStash(stash) }
                    }
                    .buttonStyle(SmallActionButtonStyle(color: Color(hex: "#3DD68C"), filled: true))
                    .font(.system(size: 10))

                    Button("Drop") {
                        Task { await vm.dropStash(stash) }
                    }
                    .buttonStyle(SmallActionButtonStyle(color: Color(hex: "#FF5A5A")))
                    .font(.system(size: 10))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color.white.opacity(0.04) : Color.clear)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(isHovered ? 0.07 : 0), lineWidth: 1))
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Apply Stash") { Task { await vm.popStash(stash) } }
            Button("Drop Stash", role: .destructive) { Task { await vm.dropStash(stash) } }
        }
    }
}

// MARK: - Quick Stash Sheet
struct QuickStashSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Binding var isPresented: Bool
    @State private var message = ""

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Stash Changes", icon: "tray.and.arrow.down.fill")

            VStack(spacing: 16) {
                GTTextField(label: "Message (optional)", text: $message, placeholder: "Work in progress...")

                let unstagedCount = vm.changes.filter { !$0.isStaged }.count
                let stagedCount = vm.changes.filter { $0.isStaged }.count

                Text("Will stash \(unstagedCount) unstaged + \(stagedCount) staged changes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)

            SheetFooter(confirmLabel: "Stash") {
                isPresented = false
                Task { await vm.stashChanges(message: message.isEmpty ? nil : message) }
            } onCancel: {
                isPresented = false
            }
        }
        .frame(width: 380)
        .background(Color(hex: "#161B22"))
    }
}
