# ServerShot

**Deploy your entire dev stack to any server with one tap from your Android device.**

The future of server provisioning is here. No more SSH-ing in and running 50 commands. No more forgetting to install that one tool. No more copy-pasting API keys. Just open the app, pick your stack, tap Deploy, and go vibe-code on a fresh server.

> Built entirely through vibe-coding with Claude Code. From zero to production app in one session.

## What is this?

ServerShot is an Android app that connects to your Linux server via SSH and deploys your complete development environment — tools, languages, configs, credentials — all in one shot.

**Think of it as Terraform, but for your personal dev setup, and it fits in your pocket.**

## Features

### One-Tap Deployment
Select the tools you need, enter your credentials, hit Deploy. Watch real-time terminal output as everything installs.

### 15 Services Out of the Box
| Category | Services |
|----------|----------|
| Containers | Docker + Docker Compose |
| Version Control | Git, GitHub CLI (auto SSH key + auth), GitLab CLI |
| Languages | Node.js (nvm), Python, Go, Rust, Ruby (rbenv) |
| Dev Tools | Claude Code (native installer + Max/Pro OAuth) |
| Editors | Neovim |
| Shell | Zsh + Oh My Zsh (with plugins), tmux |
| Networking | Tailscale, Caddy |
| Databases | PostgreSQL, Redis |

### Smart Credentials
- **GitHub**: Enter your PAT — auto-authenticates `gh`, generates SSH key, uploads it to your GitHub profile. No manual setup.
- **Claude Code**: Paste your OAuth token from `claude setup-token` — works with Max/Pro subscription. No API key billing.
- **Tailscale**: Auth key — auto-joins your tailnet.
- **PostgreSQL**: Set the postgres password during install.

### User Management
- **Create Deploy User**: Connect as root, create a non-root user with sudo (passwordless or with password), deploy everything under that user.
- **Custom SSH Users**: Add as many users as you want for quick terminal access.
- **Save without deploying**: Just add a server and its users, use Terminal whenever you need.

### Built-in SSH Terminal
Full terminal emulator powered by [xterm.dart](https://github.com/TerminalStudio/xterm.dart):
- Real VT100/ANSI rendering — vim, nano, htop all work
- Virtual key bar: Ctrl, Alt, Esc, Tab, arrows, Home/End, PgUp/PgDn, common Ctrl combos
- USB keyboard support
- Keep-alive (no random disconnects)
- User picker — choose which user to connect as

### Server Profiles
Save server configs with all credentials and users. Re-deploy or terminal in anytime.

### Presets
One-tap presets for common stacks:
- **Full Stack** — Docker, Git, GitHub CLI, Node.js, Python, Ruby, Neovim, Zsh, tmux, PostgreSQL, Redis
- **AI Dev** — Git, GitHub CLI, Node.js, Python, Claude Code, Neovim, Zsh, tmux, Docker
- **Minimal** — Git, Docker, Node.js, Zsh

## Screenshots

*Coming soon*

## Getting Started

### Install
Download the latest APK from [Releases](../../releases) and install on your Android device.

### Build from source
```bash
git clone https://github.com/your-username/android-shot.git
cd android-shot
flutter pub get
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

### Create a release
```bash
git tag v1.0.0
git push origin v1.0.0
```
GitHub Actions will build the APK and create a release automatically.

## Tech Stack

- **Flutter** + **Dart** — cross-platform UI
- **dartssh2** — SSH client in pure Dart
- **xterm.dart** — terminal emulator
- **Material 3** — dark theme, premium feel
- **Provider** — state management
- **SharedPreferences** — local storage

## Architecture

```
lib/
├── main.dart                      # App entry + splash screen
├── models/
│   ├── server_profile.dart        # Server config model
│   └── service_definition.dart    # Service/tool definition model
├── providers/
│   └── app_provider.dart          # State management
├── screens/
│   ├── home_screen.dart           # Server list + actions
│   ├── server_setup_screen.dart   # 3-step wizard (Connection → Services → Review)
│   ├── credentials_screen.dart    # API keys & tokens
│   ├── deploy_screen.dart         # Live deployment with terminal output
│   └── ssh_terminal_screen.dart   # Full SSH terminal
├── services/
│   ├── ssh_service.dart           # SSH connection & command execution
│   ├── deployment_service.dart    # Deployment orchestration
│   ├── service_registry.dart      # All 15 service definitions + install scripts
│   └── storage_service.dart       # Profile persistence
├── theme/
│   └── app_theme.dart             # Material 3 dark theme
└── widgets/
    ├── gradient_card.dart         # Glowing card widget
    ├── service_chip.dart          # Service selection chip
    ├── terminal_view.dart         # Deployment log viewer
    └── status_badge.dart          # Install status indicator
```

## Vibe-Coded

This entire app was built in a single vibe-coding session with [Claude Code](https://claude.ai/claude-code). Every line of Dart, every install script, every UI component — generated through conversation. The future is already here.

## License

MIT
