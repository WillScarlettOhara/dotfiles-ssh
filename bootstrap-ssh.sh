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
WHITE='\033[1;37m'
DIM='\033[2m'

# ─── UI HELPERS ───────────────────────────────────────────────────────────────
step() { echo -e "\n${BOLD}${BLUE}══>${RESET}${BOLD} $1${RESET}"; }
ok() { echo -e "  ${GREEN}✔${RESET}  $1"; }
warn() { echo -e "  ${YELLOW}⚠${RESET}   $1"; }
error() { echo -e "  ${RED}✘${RESET}  $1" >&2; }
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
  echo -e "  ${DIM}SSH Environment Bootstrap — $(hostname) — $(date '+%Y-%m-%d %H:%M')${RESET}\n"
}

confirm() {
  local prompt="${1:-Continue?}"
  read -rp "  ${YELLOW}?${RESET}  ${prompt} [y/N] " reply
  [[ "${reply,,}" =~ ^(y|yes)$ ]]
}

# ─── DISTRO DETECTION ─────────────────────────────────────────────────────────
detect_distro() {
  if [ -f /etc/os-release ]; then
    source /etc/os-release
    DISTRO_ID="${ID,,}"
    DISTRO_LIKE="${ID_LIKE:-}" # ID_LIKE is optional, default to empty
    DISTRO_LIKE="${DISTRO_LIKE,,}"
  else
    DISTRO_ID="unknown"
    DISTRO_LIKE=""
  fi

  if [[ "$DISTRO_ID" == "arch" || "$DISTRO_LIKE" == *"arch"* ]]; then
    DISTRO_FAMILY="arch"
    PKG_INSTALL="$SUDO pacman -S --noconfirm --needed"
    PKG_UPDATE="$SUDO pacman -Sy"
    PKG_QUERY="pacman -Q"
  elif [[ "$DISTRO_ID" == "fedora" || "$DISTRO_LIKE" == *"fedora"* || "$DISTRO_ID" == "rhel" || "$DISTRO_ID" == "centos" ]]; then
    DISTRO_FAMILY="fedora"
    PKG_INSTALL="$SUDO dnf install -y"
    PKG_UPDATE="$SUDO dnf check-update || true"
    PKG_QUERY="rpm -q"
  elif [[ "$DISTRO_ID" == "debian" || "$DISTRO_LIKE" == *"debian"* || "$DISTRO_ID" == "ubuntu" || "$DISTRO_LIKE" == *"ubuntu"* ]]; then
    DISTRO_FAMILY="debian"
    PKG_INSTALL="$SUDO apt-get install -y"
    PKG_UPDATE="$SUDO apt-get update -qq"
    PKG_QUERY="dpkg -l"
  else
    DISTRO_FAMILY="unknown"
    warn "Unrecognized distribution: $DISTRO_ID. Some steps may be skipped."
  fi

  ok "Detected: ${BOLD}$DISTRO_ID${RESET} (family: $DISTRO_FAMILY)"
}

# ─── COMMAND CHECK ────────────────────────────────────────────────────────────
has() { command -v "$1" &>/dev/null; }

# Root doesn't need sudo (and sudo is often absent on minimal servers)
if [ "$EUID" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

# ─── STEP 1: BASE PACKAGES ────────────────────────────────────────────────────
install_base_packages() {
  step "Installing base packages"
  info "Updating package index..."
  eval "$PKG_UPDATE" &>/dev/null || {
    error "Failed to update package index."
    return 1
  }

  local common_deps=(curl git wget unzip tar)

  case "$DISTRO_FAMILY" in
  debian) local extra=(zsh build-essential ca-certificates gnupg apt-transport-https) ;;
  fedora) local extra=(zsh gcc make ca-certificates gnupg2) ;;
  arch) local extra=(zsh base-devel ca-certificates gnupg) ;;
  *) local extra=() ;;
  esac

  eval "$PKG_INSTALL ${common_deps[*]} ${extra[*]}" &>/dev/null
  ok "Base packages installed"
}

# ─── STEP 2: BITWARDEN CLI ────────────────────────────────────────────────────
install_bitwarden_cli() {
  step "Installing Bitwarden CLI"

  if has bw; then
    ok "Bitwarden CLI already present ($(bw --version))"
    return
  fi

  # On Arch: prefer paru/yay
  if [[ "$DISTRO_FAMILY" == "arch" ]]; then
    if has paru; then
      paru -S --noconfirm bitwarden-cli &>/dev/null && ok "Bitwarden CLI installed ($(bw --version))" && return
    elif has yay; then
      yay -S --noconfirm bitwarden-cli &>/dev/null && ok "Bitwarden CLI installed ($(bw --version))" && return
    fi
  fi

  # All distros: official binary via Bitwarden's dynamic URL (no Node.js needed)
  info "Downloading official Bitwarden CLI binary..."
  eval "$PKG_INSTALL wget unzip jq" &>/dev/null
  wget -qO /tmp/bw.zip "https://vault.bitwarden.com/download/?app=cli&platform=linux"
  unzip -q /tmp/bw.zip -d /tmp/bw_extract
  $SUDO install -m 755 /tmp/bw_extract/bw /usr/local/bin/bw
  rm -rf /tmp/bw.zip /tmp/bw_extract

  ok "Bitwarden CLI installed ($(bw --version))"
}

# ─── STEP 3: SSH KEYS VIA BITWARDEN ──────────────────────────────────────────
setup_ssh_keys() {
  step "Fetching SSH keys from Bitwarden"

  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  # ── Login / Unlock ──────────────────────────────────────────────────────────
  local bw_status
  bw_status=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "error")

  if [[ "$bw_status" == "unauthenticated" ]]; then
    info "Bitwarden login required..."
    bw login </dev/tty
  fi

  export BW_SESSION
  local attempts=0
  while true; do
    attempts=$((attempts + 1))
    echo -e "\n  ${YELLOW}🔓${RESET} Vault locked. Enter your master password (attempt $attempts/3): \c"
    read -s -r BW_PASS </dev/tty
    echo ""
    export BW_PASS
    BW_SESSION=$(bw unlock --raw --passwordenv BW_PASS 2>/dev/null)
    unset BW_PASS

    if [ -n "${BW_SESSION:-}" ]; then
      ok "✅ Vault unlocked"
      break
    fi

    error "❌ Wrong password, try again."
    if [ "$attempts" -ge 3 ]; then
      warn "3 failed attempts — SSH key step skipped, bootstrap continues."
      return 0
    fi
  done

  # Sync vault
  info "Syncing vault..."
  bw sync &>/dev/null

  # ── Fetch SSH keys (native Bitwarden SSH Key item type) ─────────────────────
  local private_key public_key
  private_key=$(bw get item "$BW_ITEM_SSH_KEY" | jq -r '.sshKey.privateKey // empty')
  public_key=$(bw get item "$BW_ITEM_SSH_KEY" | jq -r '.sshKey.publicKey  // empty')

  if [ -n "$private_key" ]; then
    printf '%s\n' "$private_key" >"$SSH_KEY_PATH"
    printf '%s\n' "$public_key" >"${SSH_KEY_PATH}.pub"
    chmod 600 "$SSH_KEY_PATH"
    chmod 644 "${SSH_KEY_PATH}.pub"
    ok "SSH key deployed → $SSH_KEY_PATH"
  else
    warn "Empty sshKey field for item '${BW_ITEM_SSH_KEY}'."
    warn "Make sure the item type is 'SSH Key' in Bitwarden."
  fi

  # ── known_hosts: GitHub only ─────────────────────────────────────────────────
  info "Adding github.com to known_hosts..."
  ssh-keyscan github.com >>"$HOME/.ssh/known_hosts" 2>/dev/null
  chmod 644 "$HOME/.ssh/known_hosts"
  ok "known_hosts updated"

  # ── Lock vault ───────────────────────────────────────────────────────────────
  bw lock &>/dev/null || true
  unset BW_SESSION
}

# ─── STEP 4: ESSENTIAL TOOLS ──────────────────────────────────────────────────
install_tools() {
  step "Installing essential tools"

  _install_zoxide
  _install_lsd
  _install_fzf
  _install_neovim
  _install_neovim_deps
  _install_lazygit
  _install_zsh_plugins

  ok "All tools installed"
}

# ─── STEP 5: DOCKER ───────────────────────────────────────────────────────────
install_docker() {
  step "Installation de Docker"

  if has docker; then
    ok "Docker already present ($(docker --version))"
    return
  fi

  case "$DISTRO_FAMILY" in
  arch)
    eval "$PKG_INSTALL docker docker-compose" &>/dev/null
    $SUDO systemctl enable --now docker &>/dev/null
    ;;
  debian | fedora | *)
    # Official Docker convenience script — works on Debian/Ubuntu/Fedora/CentOS
    info "Downloading official Docker install script..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    info "Running Docker installer..."
    $SUDO sh /tmp/get-docker.sh &>/dev/null
    rm -f /tmp/get-docker.sh
    $SUDO systemctl enable --now docker &>/dev/null
    ;;
  esac

  # Add current user to docker group (avoids sudo on every command)
  if getent group docker &>/dev/null; then
    $SUDO usermod -aG docker "$USER"
    warn "Added to 'docker' group — effective on next SSH login"
  fi

  ok "Docker installed ($(docker --version))"
}

_install_zoxide() {
  if has zoxide; then
    ok "zoxide already present"
    return
  fi
  info "Installing zoxide..."
  case "$DISTRO_FAMILY" in
  arch | fedora) eval "$PKG_INSTALL zoxide" &>/dev/null ;;
  *) curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash &>/dev/null ;;
  esac
  ok "zoxide installed"
}

_install_lsd() {
  if has lsd; then
    ok "lsd already present"
    return
  fi
  info "Installing lsd..."
  case "$DISTRO_FAMILY" in
  arch | fedora) eval "$PKG_INSTALL lsd" &>/dev/null ;;
  debian | *)
    local lsd_url
    lsd_url=$(curl -s https://api.github.com/repos/lsd-rs/lsd/releases/latest |
      grep "browser_download_url.*amd64.deb" | cut -d'"' -f4 | head -1)
    if [ -n "$lsd_url" ]; then
      local tmp_deb
      tmp_deb=$(mktemp --suffix=.deb)
      curl -fsSL "$lsd_url" -o "$tmp_deb" &>/dev/null
      $SUDO dpkg -i "$tmp_deb" &>/dev/null
      rm -f "$tmp_deb"
    else
      warn "Could not download lsd for Debian/Ubuntu"
    fi
    ;;
  esac
  ok "lsd installed"
}

_install_fzf() {
  if has fzf; then
    ok "fzf already present"
    return
  fi
  info "Installing fzf..."
  eval "$PKG_INSTALL fzf" &>/dev/null
  ok "fzf installed"
}

_install_neovim() {
  # Check nvim actually runs — AppImage without FUSE reports as present but crashes
  if has nvim && nvim --version &>/dev/null; then
    ok "neovim already present ($(nvim --version | head -1))"
    _sync_neovim_config
    return
  fi

  if has nvim; then
    warn "neovim found but not functional (broken AppImage?) — reinstalling..."
    $SUDO rm -f "$(command -v nvim)" 2>/dev/null || true
    $SUDO rm -f /usr/local/bin/nvim 2>/dev/null || true
    $SUDO rm -rf /opt/nvim-linux-x86_64 2>/dev/null || true
  fi

  info "Installing neovim (official tar.gz)..."
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
  ok "neovim installed ($(nvim --version | head -1))"
}

_install_neovim_deps() {
  info "Installing neovim dependencies..."

  _pkg_install_verbose() {
    local pkg="$1"
    info "  installing ${pkg}..."
    if eval "$PKG_INSTALL $pkg" &>/dev/null; then
      ok "  ${pkg} ✔"
    else
      warn "  ${pkg} — failed (skipped)"
    fi
  }

  case "$DISTRO_FAMILY" in
  arch)
    for pkg in lua luarocks ripgrep fd tree-sitter xclip xsel; do
      _pkg_install_verbose "$pkg"
    done
    ;;
  fedora)
    for pkg in lua luarocks ripgrep fd-find xclip xsel; do
      _pkg_install_verbose "$pkg"
    done
    if has cargo; then
      info "  installing tree-sitter-cli via cargo..."
      cargo install tree-sitter-cli &>/dev/null && ok "  tree-sitter-cli ✔" || warn "  tree-sitter-cli — cargo install failed"
    else
      warn "  tree-sitter-cli skipped (no cargo found)"
    fi
    ;;
  debian | *)
    for pkg in lua5.4 luarocks ripgrep fd-find xclip xsel; do
      _pkg_install_verbose "$pkg"
    done
    # fd-find ships as 'fdfind' on Debian/Ubuntu — create symlink
    if has fdfind && ! has fd; then
      mkdir -p "$HOME/.local/bin"
      ln -sfn "$(command -v fdfind)" "$HOME/.local/bin/fd"
      ok "  fd symlink → fdfind ✔"
    fi
    # tree-sitter-cli: no official Debian package
    if has npm; then
      info "  installing tree-sitter-cli via npm..."
      $SUDO npm install -g tree-sitter-cli &>/dev/null &&
        ok "  tree-sitter-cli ✔" ||
        warn "  tree-sitter-cli — npm install failed"
    elif has cargo; then
      info "  installing tree-sitter-cli via cargo..."
      cargo install tree-sitter-cli &>/dev/null &&
        ok "  tree-sitter-cli ✔" ||
        warn "  tree-sitter-cli — cargo install failed"
    else
      warn "  tree-sitter-cli skipped (no npm or cargo found)"
    fi
    ;;
  esac

  ok "Neovim dependencies done"
  # Clipboard note: xclip/xsel require X11 forwarding on headless SSH servers.
  # Neovim uses OSC52 as fallback — works natively over SSH in modern terminals.
}

_install_lazygit() {
  if has lazygit; then
    ok "lazygit already present"
    return
  fi
  info "Installing lazygit..."
  case "$DISTRO_FAMILY" in
  arch) eval "$PKG_INSTALL lazygit" &>/dev/null ;;
  fedora) eval "$PKG_INSTALL lazygit" &>/dev/null ;;
  debian | *)
    # No official Debian package — grab the latest release binary from GitHub
    local lg_url
    lg_url=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
      grep "browser_download_url.*Linux_x86_64.tar.gz" | cut -d'"' -f4 | head -1)
    if [ -n "$lg_url" ]; then
      curl -fsSL "$lg_url" -o /tmp/lazygit.tar.gz &>/dev/null
      $SUDO tar -C /usr/local/bin -xzf /tmp/lazygit.tar.gz lazygit
      rm -f /tmp/lazygit.tar.gz
    else
      warn "Could not download lazygit binary"
    fi
    ;;
  esac
  ok "lazygit installed"
}

_sync_neovim_config() {
  local nvim_config_dir="$HOME/.config/nvim"
  local nvim_dotfiles_dir="$HOME/.dotfiles-nvim"
  local nvim_repo="git@github.com:WillScarlettOhara/.dotfiles.git"

  # If config already exists as a real directory, don't overwrite it
  if [ -d "$nvim_config_dir" ] && [ ! -L "$nvim_config_dir" ]; then
    info "Neovim config already present, skipping"
    return
  fi

  # SSH key required to clone via git@
  if [ ! -f "$SSH_KEY_PATH" ]; then
    warn "SSH key not found — neovim config skipped (rerun after Bitwarden setup)"
    return
  fi

  info "Cloning neovim config from .dotfiles (sparse checkout)..."

  # Spin up a temporary ssh-agent for this clone
  local agent_pid
  eval "$(ssh-agent -s)" &>/dev/null
  agent_pid=$SSH_AGENT_PID
  ssh-add "$SSH_KEY_PATH" &>/dev/null

  if [ -d "$nvim_dotfiles_dir" ]; then
    git -C "$nvim_dotfiles_dir" pull --rebase --quiet 2>/dev/null || true
  else
    git clone --depth=1 --filter=blob:none --sparse \
      "$nvim_repo" "$nvim_dotfiles_dir" &>/dev/null &&
      git -C "$nvim_dotfiles_dir" sparse-checkout set nvim/.config/nvim &>/dev/null
  fi

  local nvim_src="$nvim_dotfiles_dir/nvim/.config/nvim"
  if [ -d "$nvim_src" ]; then
    mkdir -p "$HOME/.config"
    ln -sfn "$nvim_src" "$nvim_config_dir"
    ok "Neovim config linked → $nvim_config_dir"
  else
    warn "nvim/.config/nvim not found in .dotfiles repo"
  fi

  kill "$agent_pid" &>/dev/null || true
}

_install_zsh_plugins() {
  local ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
  if [ ! -d "$ZINIT_HOME" ]; then
    info "Installing zinit..."
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME" &>/dev/null
    ok "zinit installed"
  else
    ok "zinit already present"
  fi
}

# ─── STEP 6: SSH DOTFILES ─────────────────────────────────────────────────────
setup_dotfiles() {
  step "Setting up SSH dotfiles"

  if [ -d "$DOTFILES_DIR" ]; then
    info "Updating existing dotfiles repo..."
    git -C "$DOTFILES_DIR" pull --rebase --quiet 2>/dev/null || warn "Could not update dotfiles"
  else
    info "Cloning $DOTFILES_REPO..."
    git clone --depth=1 "$DOTFILES_REPO" "$DOTFILES_DIR" 2>/dev/null || {
      error "Could not clone repo. Check the DOTFILES_REPO URL."
      return 1
    }
  fi

  if has stow; then
    info "Applying via GNU Stow..."
    cd "$DOTFILES_DIR"
    stow --restow --target="$HOME" . 2>/dev/null || warn "stow encountered a conflict (existing files)"
  else
    _manual_link_dotfiles
  fi

  ok "SSH dotfiles applied → $DOTFILES_DIR"
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
        warn "Backup created: ${dst}.bak.*"
      fi
      ln -sfn "$src" "$dst"
      info "Linked: $src_name → $dst"
    fi
  done
}

# ─── STEP 7: DEFAULT SHELL ────────────────────────────────────────────────────
set_default_shell() {
  step "Setting zsh as default shell"

  local zsh_path
  zsh_path=$(which zsh 2>/dev/null || true)

  if [ -z "$zsh_path" ]; then
    warn "zsh not found, cannot set as default shell"
    return
  fi

  if [ "$SHELL" = "$zsh_path" ]; then
    ok "zsh is already the default shell"
    return
  fi

  if ! grep -q "$zsh_path" /etc/shells 2>/dev/null; then
    echo "$zsh_path" | $SUDO tee -a /etc/shells &>/dev/null
  fi

  if chsh -s "$zsh_path" "$USER" 2>/dev/null; then
    ok "zsh set as default shell (effective on next login)"
  else
    warn "chsh failed. Run manually: chsh -s $zsh_path"
  fi
}

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${GREEN}║            Bootstrap completed successfully!             ║${RESET}"
  echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  ${BOLD}Next steps:${RESET}"
  echo -e "  ${CYAN}1.${RESET} Run ${BOLD}zsh${RESET} or open a new SSH session"
  echo -e "  ${CYAN}2.${RESET} Reconnect to apply docker group membership"
  echo -e "  ${CYAN}3.${RESET} Check your SSH key: ${BOLD}ls -la ~/.ssh/${RESET}"
  echo -e "  ${CYAN}4.${RESET} Edit ${BOLD}~/.dotfiles-ssh/zshrc${RESET} to customize"
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
  echo -e "  ${CYAN}[1]${RESET} Everything (recommended)"
  echo -e "  ${CYAN}[2]${RESET} Packages + tools only (skip Bitwarden)"
  echo -e "  ${CYAN}[3]${RESET} Bitwarden + SSH keys only"
  echo -e "  ${CYAN}[4]${RESET} Dotfiles only"
  echo -e "  ${CYAN}[5]${RESET} Docker only"
  echo -e "  ${CYAN}[q]${RESET} Quit"
  echo ""
  read -rp "  Choice [1]: " choice
  choice="${choice:-1}"

  case "$choice" in
  1)
    install_base_packages
    install_bitwarden_cli
    setup_ssh_keys
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
    echo "Goodbye!"
    exit 0
    ;;
  *)
    warn "Invalid choice, running full install"
    install_base_packages
    install_bitwarden_cli
    setup_ssh_keys
    install_tools
    install_docker
    setup_dotfiles
    set_default_shell
    ;;
  esac

  print_summary
}

# ─── ENTRY POINT ──────────────────────────────────────────────────────────────
# Non-interactive mode when piped (curl | bash) → install everything
if [ -t 0 ]; then
  run_interactive
else
  banner
  detect_distro
  install_base_packages
  install_bitwarden_cli
  setup_ssh_keys
  install_tools
  install_docker
  setup_dotfiles
  set_default_shell
  print_summary
fi
