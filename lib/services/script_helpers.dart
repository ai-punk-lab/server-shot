/// Shell helper that detects the OS package manager and provides
/// unified install/update commands for all scripts.
/// Injected at the start of every deploy script via base64.
const String osDetectPreamble = r'''
# --- ServerShot OS Detection ---
detect_pkg_manager() {
  if command -v apt-get &>/dev/null; then
    PKG=apt
    PKG_UPDATE="sudo apt-get update -qq"
    PKG_INSTALL="sudo apt-get install -y -qq"
  elif command -v dnf &>/dev/null; then
    PKG=dnf
    PKG_UPDATE="sudo dnf makecache -q"
    PKG_INSTALL="sudo dnf install -y -q"
  elif command -v yum &>/dev/null; then
    PKG=yum
    PKG_UPDATE="sudo yum makecache -q"
    PKG_INSTALL="sudo yum install -y -q"
  elif command -v pacman &>/dev/null; then
    PKG=pacman
    PKG_UPDATE="sudo pacman -Sy --noconfirm"
    PKG_INSTALL="sudo pacman -S --noconfirm"
  elif command -v apk &>/dev/null; then
    PKG=apk
    PKG_UPDATE="sudo apk update"
    PKG_INSTALL="sudo apk add --no-cache"
  elif command -v zypper &>/dev/null; then
    PKG=zypper
    PKG_UPDATE="sudo zypper refresh -q"
    PKG_INSTALL="sudo zypper install -y -q"
  else
    echo "ERROR: No supported package manager found"
    exit 1
  fi
  echo "Detected package manager: $PKG"
}

# Map package names across distros
# Usage: pkg_name <generic_name>
pkg_name() {
  case "$1" in
    python3-venv)
      case $PKG in
        dnf|yum) echo "python3" ;;  # venv included
        pacman) echo "python" ;;
        apk) echo "python3" ;;
        *) echo "python3-venv" ;;
      esac ;;
    python3-pip)
      case $PKG in
        pacman) echo "python-pip" ;;
        apk) echo "py3-pip" ;;
        *) echo "python3-pip" ;;
      esac ;;
    python3-full)
      case $PKG in
        apt) echo "python3-full" ;;
        *) echo "" ;;  # not needed on other distros
      esac ;;
    build-essential)
      case $PKG in
        dnf|yum) echo "gcc gcc-c++ make" ;;
        pacman) echo "base-devel" ;;
        apk) echo "build-base" ;;
        zypper) echo "gcc gcc-c++ make" ;;
        *) echo "build-essential" ;;
      esac ;;
    libssl-dev)
      case $PKG in
        dnf|yum) echo "openssl-devel" ;;
        pacman) echo "openssl" ;;
        apk) echo "openssl-dev" ;;
        zypper) echo "libopenssl-devel" ;;
        *) echo "libssl-dev" ;;
      esac ;;
    libreadline-dev)
      case $PKG in
        dnf|yum) echo "readline-devel" ;;
        pacman) echo "readline" ;;
        apk) echo "readline-dev" ;;
        *) echo "libreadline-dev" ;;
      esac ;;
    zlib1g-dev)
      case $PKG in
        dnf|yum) echo "zlib-devel" ;;
        pacman) echo "zlib" ;;
        apk) echo "zlib-dev" ;;
        *) echo "zlib1g-dev" ;;
      esac ;;
    libffi-dev)
      case $PKG in
        dnf|yum) echo "libffi-devel" ;;
        pacman) echo "libffi" ;;
        apk) echo "libffi-dev" ;;
        *) echo "libffi-dev" ;;
      esac ;;
    libyaml-dev)
      case $PKG in
        dnf|yum) echo "libyaml-devel" ;;
        pacman) echo "libyaml" ;;
        apk) echo "yaml-dev" ;;
        *) echo "libyaml-dev" ;;
      esac ;;
    software-properties-common)
      case $PKG in
        apt) echo "software-properties-common" ;;
        *) echo "" ;;  # not needed
      esac ;;
    *) echo "$1" ;;
  esac
}

# Install packages with auto-mapping
# Usage: pkg_install pkg1 pkg2 ...
pkg_install() {
  local pkgs=""
  for p in "$@"; do
    local mapped=$(pkg_name "$p")
    if [ -n "$mapped" ]; then
      pkgs="$pkgs $mapped"
    fi
  done
  if [ -n "$pkgs" ]; then
    $PKG_INSTALL $pkgs
  fi
}

detect_pkg_manager
''';
