# GitTree

A visual Git & GitHub manager for macOS. Built with SwiftUI, no external dependencies.

---

## Requirements

| Requirement | Minimum | Notes |
|---|---|---|
| macOS | 13.0 (Ventura) | All M-chip Macs supported |
| Git | Any modern version | Included with Xcode Command Line Tools |
| GitHub CLI | Any modern version | Required only for GitHub tab features |
| Architecture | arm64 (Apple Silicon) | M1, M2, M3, M4 |

### Install dependencies

```bash
# Install Xcode Command Line Tools (includes git)
xcode-select --install

# Install GitHub CLI
brew install gh

# Authenticate GitHub CLI
gh auth login
```

---

## Installation

Double-click `GitTree.pkg` and follow the installer. The app is installed to `/Applications/GitTree.app`.

> **First launch note:** Since the app is not signed with an Apple Developer ID, macOS Gatekeeper may block it. Right-click the app → **Open** → confirm once. It will open normally on every subsequent launch.

---

## Features

### Home Tab
- GitHub connection test button with live status indicator
- Connected account info (username, repo count, followers)
- Recent repositories list with quick open
- Quick action buttons: Open Repository, Initialize Repository, Go to GitHub

### Local Tab — Git Repository Management

#### Repository
- Open any folder as a git repository
- Initialize a new git repository (`git init`)
- Auto-detects git repositories and shows setup prompts if not initialized

#### Branches (left sidebar)
- List all local and remote branches
- Current branch highlighted with indicator
- Ahead/behind tracking counts per branch
- **Create** new branch from current HEAD
- **Checkout** branch (single click or context menu)
- **Rename** branch (inline editing)
- **Delete** branch (safe or force)
- **Merge** branch into current
- **Push** branch to remote

#### Detached HEAD state
- Prominent orange warning banner when in detached HEAD
- Shows exact commit hash of current position
- **Create New Branch Here** — saves work as a new branch at the current commit
- **Move Existing Branch Here** — force-moves any local branch pointer to the current commit (`git branch -f`)
- **Return to branch** — quick escape back to last known branch

#### Commit History (center panel)
- Visual branch graph with colored lane lines (Canvas-drawn)
- Commit hash, author, date, message per row
- Branch/tag ref badges on each commit
- Right-click context menu per commit:
  - **Checkout Commit** — enters detached HEAD at that point
  - **Revert Commit** — creates a new undo commit
  - **Reset to Here** — soft, mixed, or hard reset
  - **Copy Hash** / **Copy Short Hash**

#### Changes & Staging (center panel)
- Live working tree status (staged vs unstaged)
- Per-file status icons: Added, Modified, Deleted, Renamed, Untracked, Conflict
- **Stage** / **Unstage** individual files
- **Discard** changes in a file
- **Stage All** button
- Inline diff viewer (color-coded +/- lines)

#### Commit
- Commit message sheet with staged file preview
- Quick stage-all from commit sheet
- Amend last commit

#### Remote Operations
- **Fetch** — download without merging
- **Pull** — fetch + merge current branch
- **Push** — auto-detects missing upstream and sets `-u` automatically for new branches
- Add remote (`git remote add`)

#### Stash Manager (center panel)
- List all stashes with description and date
- **Create stash** with optional message
- **Apply (pop)** stash
- **Drop** stash
- Context menu per stash entry

#### Diff Viewer (right panel)
- Syntax-colored diff for selected file or commit
- Added lines (green), removed lines (red), hunk headers (blue)
- Horizontal scroll for long lines
- Text selection enabled

### GitHub Tab

#### Authentication
- Detects `gh auth status` automatically on launch
- Shows account info: avatar, username, public repos, followers, following
- Re-test connection button
- Step-by-step instructions when not authenticated

#### Repositories
- List all your GitHub repositories (public + private)
- Search by name or description
- Filter: All / Public / Private
- Sort: Updated / Name / Stars
- Per-repo: language badge, star count, fork count, last updated
- **Clone** to local folder (opens folder picker)
- **Open in browser**
- **Delete** with confirmation dialog
- **View Pull Requests** / **View Issues** for any repo
- **Create new repository** with:
  - Name, description, public/private toggle
  - Initialize with README option
  - Link to local folder and push initial commit

#### Pull Requests
- List open PRs for selected repository
- Shows: number, title, head→base branches, author, date, draft status
- **Merge** PR
- **Open in browser**

#### Issues
- List open issues for selected repository
- Shows: number, title, labels, author, date
- **Create new issue** with title and description
- **Close** issue

### Admin Permissions
- Automatically detects "Permission denied" errors from git
- Prompts for macOS administrator password via system dialog (AppleScript)
- `runWithAdminPrivileges()` available for protected directory operations

---

## Building from Source

```bash
# Open in Xcode
open GitTree.xcodeproj

# Or build from terminal
xcodebuild -project GitTree.xcodeproj -scheme GitTree -configuration Debug build
```

## Packaging

```bash
# Step 1: Build release archive and export app
bash scripts/build_release.sh

# Step 2: Create .pkg installer
bash scripts/package_pkg.sh

# Output: build/GitTree.pkg
```

---

## Project Structure

```
GitTree/
├── App/
│   └── GitTreeApp.swift          — Entry point, menu commands
├── Models/
│   └── Models.swift              — All data types
├── Services/
│   ├── ProcessRunner.swift       — Shell command executor (actor)
│   ├── GitService.swift          — All git operations
│   └── GitHubService.swift       — All gh CLI operations
├── ViewModels/
│   └── AppViewModel.swift        — Central state & all actions
└── Views/
    ├── ContentView.swift          — Main layout, toolbar, sheets
    ├── HomeView.swift             — Home tab
    ├── LocalView/
    │   ├── LocalRepositoryView.swift
    │   ├── BranchSidebar.swift    — Branch list + detached HEAD banner
    │   ├── CommitHistoryView.swift — Visual graph + commit rows
    │   ├── ChangesView.swift      — Staging area
    │   ├── CommitDetailView.swift — Commit metadata + actions
    │   ├── DiffView.swift         — Color-coded diff
    │   └── StashView.swift        — Stash manager
    └── GitHubView/
        ├── GitHubView.swift       — Auth, sidebar, PR/Issue tabs
        └── RepoListView.swift     — Repo list + create repo sheet
```

---

## Bundle ID
`com.elportela.GitTree`

## Copyright
© 2025 Enrique L. Portela
