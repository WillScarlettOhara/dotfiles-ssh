#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  bootstrap-ssh.sh — Ready-to-work SSH environment in seconds
#  Usage : curl -fsSL https://raw.githubusercontent.com/WillScarlettOhara/dotfiles-ssh/main/bootstrap-ssh.sh | bash
#          or   : bash bootstrap-ssh.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ─── CONFIGURATION ────────────────────────────────────────────────────────────
DOTFILES_REPO="https://github.com/WillScarlettOhara/dotfiles-ssh"
DOTFILES_DIR="$HOME/.dotfiles-ssh"
BW_ITEM_SSH_KEY="SSH GitHub"
SSH_KEY_PATH="$HOME/.ssh/id_rsa"

# ─── COLORS ───────────────────────────────────────────────────────────────────
RESET='\033[0m'
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'

# ─── UI HELPERS ───────────────────────────────────────────────────────────────
step() { echo -e "\n${BOLD}${BLUE}══▶${RESET}${BOLD} $1${RESET}"; }
ok() { echo -e "  ${GREEN}✅${RESET}  $1"; }
warn() { echo -e "  ${YELLOW}⚠️${RESET}   $1"; }
error() { echo -e "  ${RED}❌${RESET}  $1" >&2; }
info() { echo -e "  ${DIM}→${RESET}  $1"; }

banner() {
  echo -e "${CYAN}"
  echo '  ██████╗  ██████╗  ██████╗ ████████╗███████╗████████╗██████╗  █████╗ ██████╗ '
  echo '  ██╔══██╗██╔═══██╗██╔═══██╗╚══██╔══╝██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██╔══██╗'
  echo '  ██████╔╝██║   ██║██║   ██║   ██║   ███████╗   ██║   ██████╔╝███████║██████╔╝'
  echo '  ██╔══██╗██║   ██║██║   ██║   ██║   ╚════██║   ██║   ██╔══██╗██╔══██║██╔═══╝ '
  echo '  ██████╔╝╚██████╔╝╚██████╔╝   ██║   ███████║   ██║   ██║  ██║██║  ██║██║     '
  echo '  ╚═════╝  ╚═════╝  ╚═════╝    ╚═╝   ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     '
  echo -e "${RESET}"
  echo -e "  ${DIM}🖥️  SSH Environment Bootstrap — $(hostname) — $(date '+%Y-%m-%d %H:%M')${RESET}\n"
}

# ─── DISTRO DETECTION ─────────────────────────────────────────────────────────
detect_distro() {
  if [ -f /etc/os-release ]; then
    source /etc/os-release
    DISTRO_ID="${ID,,}"
    DISTRO_LIKE="${ID_LIKE:-}"
    DISTRO_LIKE="${DISTRO_LIKE,,}"
  else
    DISTRO_ID="unknown"
    DISTRO_LIKE=""
  fi

  if [[ "$DISTRO_ID" == "arch" || "$DISTRO_LIKE" == *"arch"* ]]; then
    DISTRO_FAMILY="arch"
    PKG_INSTALL="$SUDO pacman -S --noconfirm --needed"
    PKG_UPDATE="$SUDO pacman -Sy"
  elif [[ "$DISTRO_ID" == "fedora" || "$DISTRO_LIKE" == *"fedora"* || "$DISTRO_ID" == "rhel" || "$DISTRO_ID" == "centos" ]]; then
    DISTRO_FAMILY="fedora"
    PKG_INSTALL="$SUDO dnf install -y"
    PKG_UPDATE="$SUDO dnf check-update || true"
  elif [[ "$DISTRO_ID" == "debian" || "$DISTRO_LIKE" == *"debian"* || "$DISTRO_ID" == "ubuntu" || "$DISTRO_LIKE" == *"ubuntu"* ]]; then
    DISTRO_FAMILY="debian"
    PKG_INSTALL="$SUDO apt-get install -y"
    PKG_UPDATE="$SUDO apt-get update -qq"
  else
    DISTRO_FAMILY="unknown"
    warn "Unrecognized distribution: $DISTRO_ID. Some steps may be skipped."
  fi

  ok "🐧 Detected: ${BOLD}$DISTRO_ID${RESET} (family: $DISTRO_FAMILY)"
}

# ─── HELPERS ──────────────────────────────────────────────────────────────────
has() { command -v "$1" &>/dev/null; }

# Root doesn't need sudo (and sudo is often absent on minimal servers)
if [ "$EUID" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

# ─── STEP 1: BASE PACKAGES ────────────────────────────────────────────────────
install_base_packages() {
  step "📦 Installing base packages"
  info "Updating package index..."
  eval "$PKG_UPDATE" &>/dev/null || {
    error "Failed to update package index."
    return 1
  }

  local common_deps=(curl git wget unzip tar jq)

  case "$DISTRO_FAMILY" in
  debian) local extra=(zsh build-essential ca-certificates gnupg apt-transport-https openssh-server) ;;
  fedora) local extra=(zsh gcc make ca-certificates gnupg2 openssh-server) ;;
  arch) local extra=(zsh base-devel ca-certificates gnupg openssh) ;;
  *) local extra=() ;;
  esac

  eval "$PKG_INSTALL ${common_deps[*]} ${extra[*]}" &>/dev/null
  ok "📦 Base packages installed"
}

# ─── NODE VIA NVM ─────────────────────────────────────────────────────────────
_setup_node_env() {
  export NVM_DIR="$HOME/.nvm"

  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    info "📥 Installing NVM..."
    curl -s -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash &>/dev/null
  fi

  # shellcheck disable=SC1091
  \. "$NVM_DIR/nvm.sh"

  if ! has node; then
    info "📥 Installing Node.js 24 via NVM..."
    nvm install 24 &>/dev/null
    nvm use 24 &>/dev/null
    ok "⬡  Node $(node -v) & NPM $(npm -v) ready"
  else
    ok "⬡  Node $(node -v) already present"
  fi
}

# ─── STEP 2: BITWARDEN CLI ────────────────────────────────────────────────────
install_bitwarden_cli() {
  step "🔐 Checking Bitwarden CLI"

  _setup_node_env

  local current_version="0.0.0"
  local latest_version
  latest_version=$(curl -s "https://api.github.com/repos/bitwarden/clients/releases" |
    jq -r '[.[] | select(.name | contains("CLI"))][0].tag_name' | sed 's/cli-v//' || echo "")

  if has bw; then
    current_version=$(NODE_NO_WARNINGS=1 bw --version 2>/dev/null || echo "0.0.0")

    if [[ "$current_version" == "$latest_version" && "$current_version" != "0.0.0" ]]; then
      ok "🔐 Bitwarden CLI is up to date ($current_version)"
      return
    elif [[ "$current_version" != "0.0.0" ]]; then
      info "🔄 Update available: $current_version → $latest_version"
    else
      warn "Bitwarden CLI found but non-functional — reinstalling..."
    fi
  fi

  info "📥 Downloading Bitwarden CLI v$latest_version..."
  $SUDO rm -f /usr/local/bin/bw 2>/dev/null || true
  wget -q "https://vault.bitwarden.com/download/?app=cli&platform=linux" -O /tmp/bw.zip
  unzip -q -o /tmp/bw.zip -d /tmp/bw_extract
  $SUDO install -m 755 /tmp/bw_extract/bw /usr/local/bin/bw
  rm -rf /tmp/bw.zip /tmp/bw_extract

  ok "🔐 Bitwarden CLI installed ($(bw --version))"
}

# ─── STEP 3: SSH KEYS VIA BITWARDEN ──────────────────────────────────────────
setup_ssh_keys() {
  step "🗝️  Fetching SSH keys from Bitwarden"

  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  [ -s "$HOME/.nvm/nvm.sh" ] && \. "$HOME/.nvm/nvm.sh"

  local bw_status
  bw_status=$(NODE_NO_WARNINGS=1 bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "error")

  if [[ "$bw_status" == "unauthenticated" ]]; then
    info "Bitwarden login required..."
    NODE_NO_WARNINGS=1 bw login </dev/tty
  fi

  export BW_SESSION
  local attempts=0
  while true; do
    attempts=$((attempts + 1))
    echo -e "\n  ${YELLOW}🔓${RESET} Vault locked. Enter your master password (attempt $attempts/3): \c"
    read -s -r BW_PASS </dev/tty
    echo ""
    export BW_PASS
    BW_SESSION=$(NODE_NO_WARNINGS=1 bw unlock --raw --passwordenv BW_PASS 2>/dev/null || true)
    unset BW_PASS

    if [ -n "${BW_SESSION:-}" ]; then
      ok "🔓 Vault unlocked"
      break
    fi

    error "Wrong password, try again."
    if [ "$attempts" -ge 3 ]; then
      warn "3 failed attempts — SSH key step skipped, bootstrap continues."
      return 0
    fi
  done

  info "🔄 Syncing vault..."
  NODE_NO_WARNINGS=1 bw sync &>/dev/null || warn "bw sync failed, continuing anyway..."

  local private_key public_key
  private_key=$(NODE_NO_WARNINGS=1 bw get item "$BW_ITEM_SSH_KEY" 2>/dev/null | jq -r '.sshKey.privateKey // empty' || true)
  public_key=$(NODE_NO_WARNINGS=1 bw get item "$BW_ITEM_SSH_KEY" 2>/dev/null | jq -r '.sshKey.publicKey  // empty' || true)

  if [ -n "$private_key" ]; then
    printf '%s\n' "$private_key" >"$SSH_KEY_PATH"
    printf '%s\n' "$public_key" >"${SSH_KEY_PATH}.pub"
    chmod 600 "$SSH_KEY_PATH"
    chmod 644 "${SSH_KEY_PATH}.pub"
    ok "🗝️  SSH key deployed → $SSH_KEY_PATH"
  else
    warn "Empty sshKey field for item '${BW_ITEM_SSH_KEY}'."
    warn "Make sure the item type is 'SSH Key' in Bitwarden."
  fi

  info "🌐 Adding github.com to known_hosts..."
  ssh-keyscan github.com >>"$HOME/.ssh/known_hosts" 2>/dev/null
  chmod 644 "$HOME/.ssh/known_hosts"
  ok "🌐 known_hosts updated"

  NODE_NO_WARNINGS=1 bw lock &>/dev/null || true
  unset BW_SESSION
}

# ─── STEP 4: ESSENTIAL TOOLS ──────────────────────────────────────────────────
install_tools() {
  step "🛠️  Installing essential tools"

  _install_zoxide
  _install_lsd
  _install_fzf
  _install_neovim
  _install_neovim_deps
  _install_lazygit
  _install_zsh_plugins
  _bootstrap_neovim

  ok "🛠️  All tools installed"
}

# ─── STEP 5: DOCKER ───────────────────────────────────────────────────────────
install_docker() {
  step "🐳 Installing Docker"

  if has docker; then
    ok "🐳 Docker already present ($(docker --version))"
    return
  fi

  case "$DISTRO_FAMILY" in
  arch)
    eval "$PKG_INSTALL docker docker-compose" &>/dev/null
    $SUDO systemctl enable --now docker &>/dev/null
    ;;
  debian | fedora | *)
    info "📥 Downloading official Docker install script..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    info "⚙️  Running Docker installer..."
    $SUDO sh /tmp/get-docker.sh &>/dev/null
    rm -f /tmp/get-docker.sh
    $SUDO systemctl enable --now docker &>/dev/null
    ;;
  esac

  if getent group docker &>/dev/null; then
    $SUDO usermod -aG docker "$USER"
    warn "👥 Added to 'docker' group — effective on next SSH login"
  fi

  ok "🐳 Docker installed ($(docker --version))"
}

# ─── TOOL FUNCTIONS ───────────────────────────────────────────────────────────
_install_zoxide() {
  if has zoxide; then
    ok "⚡ zoxide already present"
    return
  fi
  info "📥 Installing zoxide..."
  case "$DISTRO_FAMILY" in
  arch | fedora) eval "$PKG_INSTALL zoxide" &>/dev/null ;;
  *) curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash &>/dev/null ;;
  esac
  ok "⚡ zoxide installed"
}

_install_lsd() {
  if has lsd; then
    ok "📂 lsd already present"
    return
  fi
  info "📥 Installing lsd..."
  case "$DISTRO_FAMILY" in
  arch | fedora) eval "$PKG_INSTALL lsd" &>/dev/null ;;
  debian | *)
    local lsd_url
    lsd_url=$(curl -s https://api.github.com/repos/lsd-rs/lsd/releases/latest |
      grep -Po '"browser_download_url": *"\K[^"]*amd64\.deb' | head -1 || true)
    if [ -n "$lsd_url" ]; then
      local tmp_deb
      tmp_deb=$(mktemp --suffix=.deb)
      curl -fsSL "$lsd_url" -o "$tmp_deb" &>/dev/null
      $SUDO dpkg -i "$tmp_deb" &>/dev/null || warn "lsd dpkg installation failed (skipped)"
      rm -f "$tmp_deb"
    else
      warn "Could not download lsd for Debian/Ubuntu"
    fi
    ;;
  esac
  ok "📂 lsd installed"
}

_install_fzf() {
  if has fzf; then
    ok "🔍 fzf already present"
    return
  fi
  info "📥 Installing fzf..."
  eval "$PKG_INSTALL fzf" &>/dev/null
  ok "🔍 fzf installed"
}

_install_neovim() {
  # Check nvim actually runs — AppImage without FUSE reports as present but crashes
  if has nvim && nvim --version &>/dev/null; then
    ok "📝 neovim already present ($(nvim --version | head -1))"
    _sync_neovim_config
    return
  fi

  if has nvim; then
    warn "neovim found but not functional (broken AppImage?) — reinstalling..."
    $SUDO rm -f "$(command -v nvim)" 2>/dev/null || true
    $SUDO rm -f /usr/local/bin/nvim 2>/dev/null || true
    $SUDO rm -rf /opt/nvim-linux-x86_64 2>/dev/null || true
  fi

  info "📥 Installing neovim (official tar.gz)..."
  case "$DISTRO_FAMILY" in
  arch | fedora) eval "$PKG_INSTALL neovim" &>/dev/null ;;
  debian | *)
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz &>/dev/null
    $SUDO rm -rf /opt/nvim-linux-x86_64
    $SUDO tar -C /opt -xzf nvim-linux-x86_64.tar.gz
    rm -f nvim-linux-x86_64.tar.gz
    $SUDO ln -sfn /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
    ;;
  esac
  _sync_neovim_config
  ok "📝 neovim installed ($(nvim --version | head -1))"
}

_install_neovim_deps() {
  info "📦 Installing neovim dependencies..."

  _pkg_verbose() {
    local pkg="$1"
    info "  ↳ installing ${pkg}..."
    if eval "$PKG_INSTALL $pkg" &>/dev/null; then
      ok "    ${pkg}"
    else
      warn "    ${pkg} — failed (skipped)"
    fi
  }

  case "$DISTRO_FAMILY" in
  arch)
    for pkg in lua luarocks ripgrep fd tree-sitter; do _pkg_verbose "$pkg"; done
    ;;
  fedora)
    for pkg in lua luarocks ripgrep fd-find; do _pkg_verbose "$pkg"; done
    if has cargo; then
      info "  ↳ installing tree-sitter-cli via cargo..."
      if cargo install tree-sitter-cli &>/dev/null; then ok "    tree-sitter-cli"; else warn "    tree-sitter-cli — failed"; fi
    fi
    ;;
  debian | *)
    for pkg in lua5.4 luarocks ripgrep fd-find; do _pkg_verbose "$pkg"; done

    # fd-find ships as 'fdfind' on Debian/Ubuntu — create alias
    if has fdfind && ! has fd; then
      mkdir -p "$HOME/.local/bin"
      ln -sfn "$(command -v fdfind)" "$HOME/.local/bin/fd"
      [[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"
      ok "    fd → fdfind alias created"
    fi

    # tree-sitter-cli via NVM/npm
    info "  ↳ setting up Node.js for tree-sitter-cli..."
    export NVM_DIR="$HOME/.nvm"
    if [ ! -s "$NVM_DIR/nvm.sh" ]; then
      curl -s -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash &>/dev/null
    fi
    # shellcheck disable=SC1091
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    if has nvm; then
      nvm install 24 &>/dev/null
      if npm install -g tree-sitter-cli &>/dev/null; then
        ok "    tree-sitter-cli (via npm)"
      else
        warn "    tree-sitter-cli — npm install failed"
      fi
    else
      warn "    tree-sitter-cli — nvm not available"
    fi
    ;;
  esac

  ok "📦 Neovim dependencies installed"
}

_install_lazygit() {
  if has lazygit; then
    ok "🦥 lazygit already present"
    return
  fi
  info "📥 Installing lazygit..."
  case "$DISTRO_FAMILY" in
  arch) eval "$PKG_INSTALL lazygit" &>/dev/null ;;
  fedora)
    $SUDO dnf copr enable -y dejan/lazygit &>/dev/null || true
    eval "$PKG_INSTALL lazygit" &>/dev/null
    ;;
  debian | *)
    local LAZYGIT_VERSION
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" |
      grep -Po '"tag_name": *"v\K[^"]*' || true)
    if [ -n "$LAZYGIT_VERSION" ]; then
      curl -fsSL -o /tmp/lazygit.tar.gz \
        "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" &>/dev/null
      $SUDO tar -C /usr/local/bin -xzf /tmp/lazygit.tar.gz lazygit
      rm -f /tmp/lazygit.tar.gz
    else
      warn "Could not fetch lazygit version from GitHub API"
    fi
    ;;
  esac
  ok "🦥 lazygit installed"
}

_sync_neovim_config() {
  local nvim_config_dir="$HOME/.config/nvim"
  local nvim_dotfiles_dir="$HOME/.dotfiles-nvim"
  local nvim_repo="git@github.com:WillScarlettOhara/.dotfiles.git"

  if [ ! -f "$SSH_KEY_PATH" ]; then
    warn "🗝️  SSH key not found — neovim config skipped (rerun after Bitwarden setup)"
    return
  fi

  info "🔄 Syncing neovim config from .dotfiles..."

  # Ephemeral ssh-agent for the clone
  local agent_pid
  eval "$(ssh-agent -s)" &>/dev/null
  agent_pid=$SSH_AGENT_PID
  ssh-add "$SSH_KEY_PATH" &>/dev/null

  if [ -d "$nvim_dotfiles_dir" ]; then
    info "  ↳ Updating local repo (fetch + hard reset)..."
    # fetch + hard reset avoids issues with shallow clones and rebases
    git -C "$nvim_dotfiles_dir" fetch origin master &>/dev/null &&
      git -C "$nvim_dotfiles_dir" reset --hard origin/master &>/dev/null ||
      warn "  Could not update neovim dotfiles repo"
  else
    info "  ↳ Cloning repo (sparse checkout)..."
    git clone --depth=1 --filter=blob:none --sparse --branch master \
      "$nvim_repo" "$nvim_dotfiles_dir" &>/dev/null
    git -C "$nvim_dotfiles_dir" sparse-checkout set nvim/.config/nvim &>/dev/null
  fi

  local nvim_src="$nvim_dotfiles_dir/nvim/.config/nvim"
  if [ -d "$nvim_src" ]; then
    mkdir -p "$HOME/.config"
    # Backup real directory if it exists (not a symlink)
    [ -d "$nvim_config_dir" ] && [ ! -L "$nvim_config_dir" ] &&
      mv "$nvim_config_dir" "${nvim_config_dir}.bak.$(date +%s)"
    ln -sfn "$nvim_src" "$nvim_config_dir"
    ok "📝 Neovim config linked → $nvim_config_dir"
  else
    error "nvim/.config/nvim not found in repo — check your folder structure."
  fi

  if has nvim; then
    info "  ↳ Updating Neovim plugins (headless)..."
    nvim --headless "+Lazy! sync" +qa &>/dev/null || true
  fi

  kill "$agent_pid" &>/dev/null || true
}

_bootstrap_neovim() {
  if ! has nvim; then return; fi
  info "🌳 Bootstrapping Treesitter parsers (regex, bash)..."
  nvim --headless "+TSInstallSync regex bash" "+qa" &>/dev/null || true
  ok "🌳 Treesitter parsers initialized"
}

_install_zsh_plugins() {
  local ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
  if [ ! -d "$ZINIT_HOME" ]; then
    info "📥 Installing zinit..."
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME" &>/dev/null
    ok "⚡ zinit installed"
  else
    ok "⚡ zinit already present"
  fi
}

# ─── STEP 6: SSH DOTFILES ─────────────────────────────────────────────────────
setup_dotfiles() {
  step "📂 Setting up SSH dotfiles"

  if [ -d "$DOTFILES_DIR" ]; then
    info "🔄 Updating existing dotfiles repo (fetch + hard reset)..."
    # BUG FIX: pull --rebase silently fails on shallow clones with nothing to rebase.
    # fetch + hard reset is reliable in all cases.
    if git -C "$DOTFILES_DIR" fetch origin &>/dev/null &&
      git -C "$DOTFILES_DIR" reset --hard origin/HEAD &>/dev/null; then
      ok "🔄 Dotfiles repo up to date"
    else
      warn "Could not update dotfiles repo — using current local version"
    fi
  else
    info "📥 Cloning $DOTFILES_REPO..."
    git clone --depth=1 "$DOTFILES_REPO" "$DOTFILES_DIR" 2>/dev/null || {
      error "Could not clone repo. Check the DOTFILES_REPO URL."
      return 1
    }
  fi

  if has stow; then
    info "🔗 Applying via GNU Stow..."
    cd "$DOTFILES_DIR"
    stow --restow --target="$HOME" . 2>/dev/null || warn "stow encountered a conflict (existing files)"
  else
    _manual_link_dotfiles
  fi

  ok "📂 SSH dotfiles applied → $DOTFILES_DIR"
}

_manual_link_dotfiles() {
  # Repo stores 'zshrc' without the leading dot — link it to ~/.zshrc
  declare -A FILE_MAP=(
    ["zshrc"]=".zshrc"
    [".zshenv"]=".zshenv"
    [".gitconfig"]=".gitconfig"
    [".gitignore_global"]=".gitignore_global"
    ["nvim"]=".config/nvim"
  )

  for src_name in "${!FILE_MAP[@]}"; do
    local src="$DOTFILES_DIR/$src_name"
    local dst="$HOME/${FILE_MAP[$src_name]}"
    if [ -e "$src" ]; then
      mkdir -p "$(dirname "$dst")"
      if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mv "$dst" "${dst}.bak.$(date +%s)"
        warn "💾 Backup created: ${dst}.bak.*"
      fi
      ln -sfn "$src" "$dst"
      ok "🔗 Linked: $src_name → $dst"
    fi
  done
}

# ─── STEP 7: DEFAULT SHELL ────────────────────────────────────────────────────
set_default_shell() {
  step "🐚 Setting zsh as default shell"

  local zsh_path
  zsh_path=$(which zsh 2>/dev/null || true)

  if [ -z "$zsh_path" ]; then
    warn "zsh not found, cannot set as default shell"
    return
  fi

  if [ "$SHELL" = "$zsh_path" ]; then
    ok "🐚 zsh is already the default shell"
    return
  fi

  if ! grep -q "$zsh_path" /etc/shells 2>/dev/null; then
    echo "$zsh_path" | $SUDO tee -a /etc/shells &>/dev/null
  fi

  if chsh -s "$zsh_path" "$USER" 2>/dev/null; then
    ok "🐚 zsh set as default shell (effective on next login)"
  else
    warn "chsh failed. Run manually: chsh -s $zsh_path"
  fi
}

# ─── STEP 8: SECURE SSH DAEMON ────────────────────────────────────────────────
setup_ssh_daemon() {
  step "🔒 Securing SSH daemon (key-only access)"

  case "$DISTRO_FAMILY" in
  arch) eval "$PKG_INSTALL openssh" &>/dev/null ;;
  debian | fedora) eval "$PKG_INSTALL openssh-server" &>/dev/null ;;
  esac

  if [ ! -f /etc/ssh/sshd_config.bak ]; then
    $SUDO cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    info "💾 Original sshd_config backed up"
  fi

  info "⚙️  Applying hardening (PasswordAuthentication no)..."
  echo "# Configured by bootstrap-ssh.sh
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin prohibit-password
AuthorizedKeysFile .ssh/authorized_keys
ChallengeResponseAuthentication no
UsePAM yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/ssh/sftp-server
" | $SUDO tee /etc/ssh/sshd_config.d/99-hardened.conf &>/dev/null

  if ! $SUDO grep -q "Include /etc/ssh/sshd_config.d/\*.conf" /etc/ssh/sshd_config; then
    echo "Include /etc/ssh/sshd_config.d/*.conf" | $SUDO tee -a /etc/ssh/sshd_config &>/dev/null
  fi

  if [ -f "${SSH_KEY_PATH}.pub" ]; then
    mkdir -p "$HOME/.ssh"
    cat "${SSH_KEY_PATH}.pub" >>"$HOME/.ssh/authorized_keys"
    chmod 600 "$HOME/.ssh/authorized_keys"
    ok "🔑 Bitwarden SSH key added to authorized_keys"
  else
    warn "No public key found to add to authorized_keys!"
  fi

  # Use 'reload' instead of 'restart' — reload sends SIGHUP to apply the new
  # config without dropping active SSH connections (including this very session).
  info "🔄 Reloading SSH service (config applied without dropping connections)..."
  if $SUDO systemctl reload sshd &>/dev/null ||
    $SUDO systemctl reload ssh &>/dev/null; then
    ok "🔒 SSH daemon secured — new config applied (key-only access enabled)"
  else
    # Service not yet running: start it for the first time
    $SUDO systemctl enable --now sshd &>/dev/null ||
      $SUDO systemctl enable --now ssh &>/dev/null ||
      warn "Could not start SSH service"
    ok "🔒 SSH daemon started and secured"
  fi
}

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${GREEN}║          🎉 Bootstrap completed successfully! 🎉          ║${RESET}"
  echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  ${BOLD}Next steps:${RESET}"
  echo -e "  ${CYAN}1.${RESET} 🐚 Run ${BOLD}zsh${RESET} or open a new SSH session"
  echo -e "  ${CYAN}2.${RESET} 🐳 Reconnect to apply docker group membership"
  echo -e "  ${CYAN}3.${RESET} 📝 Edit ${BOLD}~/.dotfiles-ssh/zshrc${RESET} to customize"
  echo ""
  echo -e "  ${DIM}Dotfiles : $DOTFILES_DIR${RESET}"
  echo -e "  ${DIM}Bitwarden session : closed${RESET}"
  echo ""
}

# ─── INTERACTIVE MENU ─────────────────────────────────────────────────────────
run_interactive() {
  banner
  detect_distro
  echo ""

  echo -e "${BOLD}What do you want to install?${RESET}"
  echo -e "  ${CYAN}[1]${RESET} 🚀 Everything (recommended)"
  echo -e "  ${CYAN}[2]${RESET} 🛠️  Packages + tools only (skip Bitwarden)"
  echo -e "  ${CYAN}[3]${RESET} 🔐 Bitwarden + SSH keys only"
  echo -e "  ${CYAN}[4]${RESET} 📂 Dotfiles only"
  echo -e "  ${CYAN}[5]${RESET} 🐳 Docker only"
  echo -e "  ${CYAN}[q]${RESET} 👋 Quit"
  echo ""
  read -rp "  Choice [1]: " choice
  choice="${choice:-1}"

  case "$choice" in
  1)
    install_base_packages
    install_bitwarden_cli
    setup_ssh_keys
    setup_ssh_daemon
    install_tools
    install_docker
    setup_dotfiles
    set_default_shell
    ;;
  2)
    install_base_packages
    install_tools
    install_docker
    setup_dotfiles
    set_default_shell
    ;;
  3)
    install_base_packages
    install_bitwarden_cli
    setup_ssh_keys
    ;;
  4)
    setup_dotfiles
    ;;
  5)
    install_docker
    ;;
  q | Q)
    echo "👋 Goodbye!"
    exit 0
    ;;
  *)
    warn "Invalid choice, running full install"
    install_base_packages
    install_bitwarden_cli
    setup_ssh_keys
    setup_ssh_daemon
    install_tools
    install_docker
    setup_dotfiles
    set_default_shell
    ;;
  esac

  print_summary
}

# ─── ENTRY POINT ──────────────────────────────────────────────────────────────
# Non-interactive when piped (curl | bash) → full install
if [ -t 0 ]; then
  run_interactive
else
  banner
  detect_distro
  install_base_packages
  install_bitwarden_cli
  setup_ssh_keys
  setup_ssh_daemon
  install_tools
  install_docker
  setup_dotfiles
  set_default_shell
  print_summary
fi
