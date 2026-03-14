import 'package:flutter/material.dart';
import '../models/service_definition.dart';

class ServiceRegistry {
  static List<ServiceDefinition> get all => [
        // --- Containerization ---
        ServiceDefinition(
          id: 'docker',
          name: 'Docker',
          description: 'Container runtime + Docker Compose',
          iconChar: '🐳',
          category: ServiceCategory.containerization,
          accentColor: const Color(0xFF2496ED),
          installScript: (_) => r'''
set -e
echo ">>> Installing Docker..."
if command -v docker &>/dev/null; then
  echo "Docker already installed: $(docker --version)"
else
  curl -fsSL https://get.docker.com | sh
  echo "Docker installed: $(docker --version)"
fi
if ! groups | grep -q docker; then
  sudo usermod -aG docker $USER
  echo "Added $USER to docker group"
fi
# Docker Compose
if ! docker compose version &>/dev/null; then
  COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
  sudo curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
fi
echo "Docker Compose: $(docker compose version 2>/dev/null || docker-compose --version 2>/dev/null)"
echo "<<< Docker done"
''',
        ),

        // --- Version Control ---
        ServiceDefinition(
          id: 'git',
          name: 'Git',
          description: 'Latest version of Git',
          iconChar: '📦',
          category: ServiceCategory.versionControl,
          accentColor: const Color(0xFFF05032),
          credentialFields: [
            const CredentialField(
              key: 'git_name',
              label: 'Git Name',
              hint: 'Your Name',
              isSecret: false,
            ),
            const CredentialField(
              key: 'git_email',
              label: 'Git Email',
              hint: 'you@example.com',
              isSecret: false,
            ),
          ],
          installScript: (creds) => '''
set -e
echo ">>> Installing Git..."
\$PKG_UPDATE
\$PKG_INSTALL git
echo "Git installed: \$(git --version)"
${creds['git_name']?.isNotEmpty == true ? 'git config --global user.name "${creds['git_name']}"' : ''}
${creds['git_email']?.isNotEmpty == true ? 'git config --global user.email "${creds['git_email']}"' : ''}
echo "<<< Git done"
''',
        ),

        ServiceDefinition(
          id: 'github_cli',
          name: 'GitHub CLI',
          description: 'gh CLI + auth + SSH key setup',
          iconChar: '🐙',
          category: ServiceCategory.versionControl,
          dependencies: ['git'],
          accentColor: const Color(0xFF333333),
          credentialFields: [
            const CredentialField(
              key: 'github_token',
              label: 'GitHub Token',
              hint: 'ghp_xxxxxxxxxxxx',
            ),
          ],
          installScript: (creds) {
            final token = creds['github_token'] ?? '';
            return '''
set -e
echo ">>> Installing GitHub CLI..."
if ! command -v gh &>/dev/null; then
  case \$PKG in
    apt)
      \$PKG_INSTALL curl wget
      sudo mkdir -p -m 755 /etc/apt/keyrings
      wget -nv -O /tmp/gh-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg
      cat /tmp/gh-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
      sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
      \$PKG_UPDATE
      \$PKG_INSTALL gh
      ;;
    dnf|yum)
      sudo dnf install -y 'dnf-command(config-manager)' 2>/dev/null || true
      sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo 2>/dev/null || true
      \$PKG_INSTALL gh
      ;;
    pacman)
      \$PKG_INSTALL github-cli
      ;;
    apk)
      \$PKG_INSTALL github-cli
      ;;
    *)
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
      \$PKG_INSTALL gh 2>/dev/null || echo "Manual install may be needed"
      ;;
  esac
fi
echo "GitHub CLI: \$(gh --version | head -1)"

${token.isNotEmpty ? '''
echo "$token" | gh auth login --with-token
echo "GitHub auth status:"
gh auth status
if [ ! -f ~/.ssh/id_ed25519 ]; then
  ssh-keygen -t ed25519 -C "servershot-\$(hostname)" -f ~/.ssh/id_ed25519 -N ""
  echo "Generated SSH key"
fi
HOSTNAME=\$(hostname)
gh ssh-key add ~/.ssh/id_ed25519.pub --title "ServerShot-\$HOSTNAME" 2>/dev/null || echo "SSH key may already exist on GitHub"
echo "SSH key uploaded to GitHub"
gh config set git_protocol ssh
''' : '# No token provided, skipping auth'}

echo "<<< GitHub CLI done"
''';
          },
        ),

        ServiceDefinition(
          id: 'gitlab_cli',
          name: 'GitLab CLI',
          description: 'glab CLI + auth',
          iconChar: '🦊',
          category: ServiceCategory.versionControl,
          dependencies: ['git'],
          accentColor: const Color(0xFFFC6D26),
          credentialFields: [
            const CredentialField(
              key: 'gitlab_token',
              label: 'GitLab Token',
              hint: 'glpat-xxxxxxxxxxxx',
            ),
            const CredentialField(
              key: 'gitlab_host',
              label: 'GitLab Host',
              hint: 'gitlab.com',
              isSecret: false,
            ),
          ],
          installScript: (creds) {
            final token = creds['gitlab_token'] ?? '';
            final host = creds['gitlab_host']?.isNotEmpty == true
                ? creds['gitlab_host']!
                : 'gitlab.com';
            return '''
set -e
echo ">>> Installing GitLab CLI..."
if ! command -v glab &>/dev/null; then
  curl -sL "https://raw.githubusercontent.com/profclems/glab/trunk/scripts/install.sh" | sudo sh
fi
echo "GitLab CLI: \$(glab --version 2>/dev/null || echo 'installed')"

${token.isNotEmpty ? '''
glab auth login --hostname $host --token "$token"
echo "GitLab auth status:"
glab auth status
''' : '# No token provided, skipping auth'}

echo "<<< GitLab CLI done"
''';
          },
        ),

        // --- Languages ---
        ServiceDefinition(
          id: 'nodejs',
          name: 'Node.js',
          description: 'Node.js LTS + npm via nvm',
          iconChar: '💚',
          category: ServiceCategory.languages,
          accentColor: const Color(0xFF339933),
          installScript: (_) => r'''
set -e
echo ">>> Installing Node.js..."
if command -v node &>/dev/null; then
  echo "Node.js already installed: $(node --version)"
else
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  nvm install --lts
  echo "Node.js installed: $(node --version)"
  echo "npm: $(npm --version)"
fi
echo "<<< Node.js done"
''',
        ),

        ServiceDefinition(
          id: 'python',
          name: 'Python',
          description: 'Python 3 + pip + venv',
          iconChar: '🐍',
          category: ServiceCategory.languages,
          accentColor: const Color(0xFF3776AB),
          installScript: (_) => r'''
set -e
echo ">>> Installing Python..."
$PKG_UPDATE
pkg_install python3 python3-pip python3-venv python3-full
echo "Python installed: $(python3 --version)"
echo "pip: $(pip3 --version 2>/dev/null || echo 'included')"
echo "<<< Python done"
''',
        ),

        ServiceDefinition(
          id: 'golang',
          name: 'Go',
          description: 'Latest Go toolchain',
          iconChar: '🔵',
          category: ServiceCategory.languages,
          accentColor: const Color(0xFF00ADD8),
          installScript: (_) => r'''
set -e
echo ">>> Installing Go..."
if command -v go &>/dev/null; then
  echo "Go already installed: $(go version)"
else
  ARCH=$(uname -m)
  case $ARCH in
    x86_64) GOARCH="amd64" ;;
    aarch64) GOARCH="arm64" ;;
    armv7l) GOARCH="armv6l" ;;
    *) GOARCH="amd64" ;;
  esac
  GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -1)
  wget -q "https://go.dev/dl/${GO_VERSION}.linux-${GOARCH}.tar.gz" -O /tmp/go.tar.gz
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz
  rm /tmp/go.tar.gz
  echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
  export PATH=$PATH:/usr/local/go/bin
  echo "Go installed: $(go version)"
fi
echo "<<< Go done"
''',
        ),

        ServiceDefinition(
          id: 'rust',
          name: 'Rust',
          description: 'Rust toolchain via rustup',
          iconChar: '🦀',
          category: ServiceCategory.languages,
          accentColor: const Color(0xFFDEA584),
          installScript: (_) => r'''
set -e
echo ">>> Installing Rust..."
if command -v rustc &>/dev/null; then
  echo "Rust already installed: $(rustc --version)"
else
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
  echo "Rust installed: $(rustc --version)"
  echo "Cargo: $(cargo --version)"
fi
echo "<<< Rust done"
''',
        ),

        ServiceDefinition(
          id: 'ruby',
          name: 'Ruby',
          description: 'Ruby via rbenv + ruby-build',
          iconChar: '💎',
          category: ServiceCategory.languages,
          accentColor: const Color(0xFFCC342D),
          installScript: (_) => r'''
set -e
echo ">>> Installing Ruby via rbenv..."
$PKG_UPDATE
pkg_install git curl libssl-dev libreadline-dev zlib1g-dev autoconf bison build-essential libyaml-dev libffi-dev

if [ ! -d "$HOME/.rbenv" ]; then
  git clone --depth=1 https://github.com/rbenv/rbenv.git ~/.rbenv
  echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
  echo 'eval "$(rbenv init -)"' >> ~/.bashrc
fi
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

if [ ! -d "$HOME/.rbenv/plugins/ruby-build" ]; then
  git clone --depth=1 https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
fi

RUBY_LATEST=$(rbenv install -l 2>/dev/null | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
if [ -n "$RUBY_LATEST" ]; then
  if ! rbenv versions | grep -q "$RUBY_LATEST"; then
    echo "Installing Ruby $RUBY_LATEST (this may take a few minutes)..."
    rbenv install "$RUBY_LATEST"
  fi
  rbenv global "$RUBY_LATEST"
  echo "Ruby installed: $(ruby --version)"
  gem install bundler --no-document
  echo "Bundler: $(bundler --version)"
else
  echo "Installing Ruby 3.3.0..."
  rbenv install 3.3.0
  rbenv global 3.3.0
  gem install bundler --no-document
fi
echo "<<< Ruby done"
''',
        ),

        // --- Dev Tools ---
        ServiceDefinition(
          id: 'claude_code',
          name: 'Claude Code',
          description: 'Anthropic CLI — AI coding assistant',
          iconChar: '🤖',
          category: ServiceCategory.devtools,
          accentColor: const Color(0xFFD97706),
          credentialFields: [
            const CredentialField(
              key: 'claude_oauth_token',
              label: 'OAuth Token (Max/Pro)',
              hint: 'Run "claude setup-token" locally to get this',
            ),
            const CredentialField(
              key: 'anthropic_api_key',
              label: 'API Key (pay-per-use, optional)',
              hint: 'sk-ant-xxx — only if not using Max',
            ),
          ],
          installScript: (creds) {
            final oauthToken = creds['claude_oauth_token'] ?? '';
            final apiKey = creds['anthropic_api_key'] ?? '';
            return '''
set -e
echo ">>> Installing Claude Code..."

curl -fsSL https://claude.ai/install.sh | bash
export PATH="\$HOME/.claude/bin:\$PATH"
echo 'export PATH="\$HOME/.claude/bin:\$PATH"' >> ~/.bashrc

echo "Claude Code installed: \$(claude --version 2>/dev/null || echo 'installed')"

mkdir -p ~/.claude
echo '{"hasCompletedOnboarding": true}' > ~/.claude.json

${oauthToken.isNotEmpty ? '''
echo 'export CLAUDE_CODE_OAUTH_TOKEN="$oauthToken"' >> ~/.bashrc
export CLAUDE_CODE_OAUTH_TOKEN="$oauthToken"
echo "Claude Code configured with Max/Pro subscription (OAuth)"
''' : ''}

${apiKey.isNotEmpty && oauthToken.isEmpty ? '''
echo 'export ANTHROPIC_API_KEY="$apiKey"' >> ~/.bashrc
export ANTHROPIC_API_KEY="$apiKey"
echo "Claude Code configured with API key"
''' : ''}

echo "<<< Claude Code done"
''';
          },
        ),

        // --- Editors ---
        ServiceDefinition(
          id: 'neovim',
          name: 'Neovim',
          description: 'Neovim with modern defaults',
          iconChar: '✏️',
          category: ServiceCategory.editors,
          accentColor: const Color(0xFF57A143),
          installScript: (_) => r'''
set -e
echo ">>> Installing Neovim..."
if command -v nvim &>/dev/null; then
  echo "Neovim already installed: $(nvim --version | head -1)"
else
  case $PKG in
    apt)
      pkg_install software-properties-common
      sudo add-apt-repository -y ppa:neovim-ppa/unstable 2>/dev/null || true
      $PKG_UPDATE
      $PKG_INSTALL neovim || true
      ;;
    dnf|yum)
      $PKG_INSTALL neovim || true
      ;;
    pacman)
      $PKG_INSTALL neovim
      ;;
    apk)
      $PKG_INSTALL neovim
      ;;
  esac
  # Fallback: install from GitHub releases
  if ! command -v nvim &>/dev/null; then
    NVIM_VERSION=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
      curl -fsSL "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz" -o /tmp/nvim.tar.gz
      sudo tar -C /usr/local --strip-components=1 -xzf /tmp/nvim.tar.gz
      rm /tmp/nvim.tar.gz
    else
      echo "Neovim binary not available for $ARCH, try building from source"
    fi
  fi
  echo "Neovim installed: $(nvim --version | head -1)"
fi
echo "<<< Neovim done"
''',
        ),

        // --- Shell ---
        ServiceDefinition(
          id: 'zsh',
          name: 'Zsh + Oh My Zsh',
          description: 'Zsh shell with Oh My Zsh framework',
          iconChar: '🐚',
          category: ServiceCategory.shell,
          accentColor: const Color(0xFF89E051),
          installScript: (_) => r'''
set -e
echo ">>> Installing Zsh + Oh My Zsh..."
$PKG_UPDATE
$PKG_INSTALL zsh git curl

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  echo "Oh My Zsh installed"
else
  echo "Oh My Zsh already installed"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && \
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && \
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting docker)/' ~/.zshrc 2>/dev/null || true

sudo chsh -s $(which zsh) $USER 2>/dev/null || true
echo "Zsh installed: $(zsh --version)"
echo "<<< Zsh done"
''',
        ),

        ServiceDefinition(
          id: 'tmux',
          name: 'tmux',
          description: 'Terminal multiplexer',
          iconChar: '🪟',
          category: ServiceCategory.shell,
          accentColor: const Color(0xFF1BB91F),
          installScript: (_) => r'''
set -e
echo ">>> Installing tmux..."
$PKG_UPDATE
$PKG_INSTALL tmux
echo "tmux installed: $(tmux -V)"
echo "<<< tmux done"
''',
        ),

        // --- Networking ---
        ServiceDefinition(
          id: 'tailscale',
          name: 'Tailscale',
          description: 'Zero-config VPN mesh network',
          iconChar: '🔗',
          category: ServiceCategory.networking,
          accentColor: const Color(0xFF2C3E50),
          credentialFields: [
            const CredentialField(
              key: 'tailscale_authkey',
              label: 'Auth Key',
              hint: 'tskey-auth-xxxxxxxxxxxx',
            ),
          ],
          installScript: (creds) {
            final authKey = creds['tailscale_authkey'] ?? '';
            return '''
set -e
echo ">>> Installing Tailscale..."
if ! command -v tailscale &>/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
echo "Tailscale installed: \$(tailscale version | head -1)"

${authKey.isNotEmpty ? '''
sudo tailscale up --authkey="$authKey"
echo "Tailscale connected"
tailscale status
''' : '# No auth key provided, run "sudo tailscale up" manually'}

echo "<<< Tailscale done"
''';
          },
        ),

        ServiceDefinition(
          id: 'caddy',
          name: 'Caddy',
          description: 'Modern web server with auto HTTPS',
          iconChar: '🌐',
          category: ServiceCategory.networking,
          accentColor: const Color(0xFF00B8D4),
          installScript: (_) => r'''
set -e
echo ">>> Installing Caddy..."
if ! command -v caddy &>/dev/null; then
  case $PKG in
    apt)
      $PKG_INSTALL debian-keyring debian-archive-keyring apt-transport-https curl
      curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg 2>/dev/null
      curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null
      $PKG_UPDATE
      $PKG_INSTALL caddy
      ;;
    dnf|yum)
      sudo dnf install -y 'dnf-command(copr)' 2>/dev/null || true
      sudo dnf copr enable -y @caddy/caddy 2>/dev/null || true
      $PKG_INSTALL caddy
      ;;
    pacman)
      $PKG_INSTALL caddy
      ;;
    *)
      # Fallback: download binary
      curl -fsSL "https://caddyserver.com/api/download?os=linux&arch=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')" -o /usr/local/bin/caddy
      sudo chmod +x /usr/local/bin/caddy
      ;;
  esac
fi
echo "Caddy installed: $(caddy version)"
echo "<<< Caddy done"
''',
        ),

        // --- Databases ---
        ServiceDefinition(
          id: 'postgresql',
          name: 'PostgreSQL',
          description: 'PostgreSQL database server',
          iconChar: '🐘',
          category: ServiceCategory.databases,
          accentColor: const Color(0xFF336791),
          credentialFields: [
            const CredentialField(
              key: 'pg_password',
              label: 'Postgres Password',
              hint: 'Password for postgres user',
            ),
          ],
          installScript: (creds) {
            final pgPassword = creds['pg_password'] ?? 'servershot';
            return '''
set -e
echo ">>> Installing PostgreSQL..."
\$PKG_UPDATE
case \$PKG in
  apt) \$PKG_INSTALL postgresql postgresql-contrib ;;
  dnf|yum) \$PKG_INSTALL postgresql-server postgresql ;;
  pacman) \$PKG_INSTALL postgresql ;;
  apk) \$PKG_INSTALL postgresql ;;
esac

# Init DB on RHEL-based if needed
if [ -f /usr/bin/postgresql-setup ]; then
  sudo postgresql-setup --initdb 2>/dev/null || true
fi

sudo systemctl start postgresql 2>/dev/null || sudo service postgresql start 2>/dev/null || true
sudo systemctl enable postgresql 2>/dev/null || true

sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$pgPassword';" 2>/dev/null || true
echo "PostgreSQL installed: \$(psql --version)"
echo "<<< PostgreSQL done"
''';
          },
        ),

        ServiceDefinition(
          id: 'redis',
          name: 'Redis',
          description: 'In-memory data store',
          iconChar: '🔴',
          category: ServiceCategory.databases,
          accentColor: const Color(0xFFDC382D),
          installScript: (_) => r'''
set -e
echo ">>> Installing Redis..."
$PKG_UPDATE
case $PKG in
  apt) $PKG_INSTALL redis-server ;;
  dnf|yum) $PKG_INSTALL redis ;;
  pacman) $PKG_INSTALL redis ;;
  apk) $PKG_INSTALL redis ;;
esac

sudo systemctl start redis-server 2>/dev/null || sudo systemctl start redis 2>/dev/null || sudo service redis start 2>/dev/null || true
sudo systemctl enable redis-server 2>/dev/null || sudo systemctl enable redis 2>/dev/null || true
echo "Redis installed: $(redis-server --version)"
echo "<<< Redis done"
''',
        ),
      ];

  static ServiceDefinition? getById(String id) {
    try {
      return all.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  static Map<ServiceCategory, List<ServiceDefinition>> get grouped {
    final map = <ServiceCategory, List<ServiceDefinition>>{};
    for (final service in all) {
      map.putIfAbsent(service.category, () => []).add(service);
    }
    return map;
  }

  static List<String> resolveDependencies(List<String> selectedIds) {
    final resolved = <String>[];
    final visited = <String>{};

    void resolve(String id) {
      if (visited.contains(id)) return;
      visited.add(id);
      final service = getById(id);
      if (service == null) return;
      for (final dep in service.dependencies) {
        resolve(dep);
      }
      resolved.add(id);
    }

    for (final id in selectedIds) {
      resolve(id);
    }
    return resolved;
  }
}
