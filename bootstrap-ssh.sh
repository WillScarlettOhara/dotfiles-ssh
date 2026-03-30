#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  bootstrap-ssh.sh — Environnement de travail SSH en quelques secondes
#  Usage : curl -fsSL https://raw.githubusercontent.com/TON_USER/dotfiles-ssh/main/bootstrap-ssh.sh | bash
#          ou bien : bash bootstrap-ssh.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ─── CONFIGURATION ────────────────────────────────────────────────────────────
DOTFILES_REPO="https://github.com/WillScarlettOhara/dotfiles-ssh"
DOTFILES_DIR="$HOME/.dotfiles-ssh"
BW_ITEM_SSH_KEY="SSH GitHub"
SSH_KEY_PATH="$HOME/.ssh/id_rsa"

# ─── COULEURS ─────────────────────────────────────────────────────────────────
RESET='\033[0m'
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DIM='\033[2m'

# ─── HELPERS UI ───────────────────────────────────────────────────────────────
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
  local prompt="${1:-Continuer ?}"
  read -rp "  ${YELLOW}?${RESET}  ${prompt} [o/N] " reply
  [[ "${reply,,}" =~ ^(o|oui|y|yes)$ ]]
}

# ─── DÉTECTION DISTRO ─────────────────────────────────────────────────────────
detect_distro() {
  if [ -f /etc/os-release ]; then
    source /etc/os-release
    DISTRO_ID="${ID,,}"
    DISTRO_LIKE="${ID_LIKE:-}" # ID_LIKE est optionnel, valeur vide par défaut
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
    warn "Distribution non reconnue : $DISTRO_ID. Certaines étapes seront ignorées."
  fi

  ok "Distribution détectée : ${BOLD}$DISTRO_ID${RESET} (famille : $DISTRO_FAMILY)"
}

# ─── VÉRIFICATION COMMANDE ────────────────────────────────────────────────────
has() { command -v "$1" &>/dev/null; }

# Root n'a pas besoin de $SUDO (et $SUDO n'est souvent pas installé sur serveur)
if [ "$EUID" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

# ─── ÉTAPE 1 : PAQUETS DE BASE ────────────────────────────────────────────────
install_base_packages() {
  step "Installation des paquets de base"
  info "Mise à jour des dépôts..."
  eval "$PKG_UPDATE" &>/dev/null || {
    error "Échec de la mise à jour des dépôts."
    return 1
  }

  # Liste commune
  local common_deps=(curl git wget unzip tar)

  case "$DISTRO_FAMILY" in
  debian)
    local extra=(zsh build-essential ca-certificates gnupg apt-transport-https)
    ;;
  fedora)
    local extra=(zsh gcc make ca-certificates gnupg2)
    ;;
  arch)
    local extra=(zsh base-devel ca-certificates gnupg)
    ;;
  *)
    local extra=()
    ;;
  esac

  eval "$PKG_INSTALL ${common_deps[*]} ${extra[*]}" &>/dev/null
  ok "Paquets de base installés"
}

# ─── ÉTAPE 2 : BITWARDEN CLI ──────────────────────────────────────────────────
install_bitwarden_cli() {
  step "Installation de Bitwarden CLI"

  if has bw; then
    ok "Bitwarden CLI déjà présent ($(bw --version))"
    return
  fi

  # Sur Arch : paru/yay disponibles, on les préfère
  if [[ "$DISTRO_FAMILY" == "arch" ]]; then
    if has paru; then
      paru -S --noconfirm bitwarden-cli &>/dev/null && ok "Bitwarden CLI installé ($(bw --version))" && return
    elif has yay; then
      yay -S --noconfirm bitwarden-cli &>/dev/null && ok "Bitwarden CLI installé ($(bw --version))" && return
    fi
  fi

  # Toutes distros : binaire officiel via l'URL dynamique Bitwarden (sans Node.js)
  info "Téléchargement du binaire officiel Bitwarden CLI..."
  eval "$PKG_INSTALL wget unzip jq" &>/dev/null
  wget -qO /tmp/bw.zip "https://vault.bitwarden.com/download/?app=cli&platform=linux"
  unzip -q /tmp/bw.zip -d /tmp/bw_extract
  $SUDO install -m 755 /tmp/bw_extract/bw /usr/local/bin/bw
  rm -rf /tmp/bw.zip /tmp/bw_extract

  ok "Bitwarden CLI installé ($(bw --version))"
}

# ─── ÉTAPE 3 : CLÉS SSH VIA BITWARDEN ────────────────────────────────────────
setup_ssh_keys() {
  step "Récupération des clés SSH depuis Bitwarden"

  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  # ── Connexion / Déverrouillage ──────────────────────────────────────────────
  local bw_status
  bw_status=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "error")

  if [[ "$bw_status" == "unauthenticated" ]]; then
    info "Connexion à Bitwarden requise..."
    bw login </dev/tty
  fi

  export BW_SESSION
  local attempts=0
  while true; do
    attempts=$((attempts + 1))
    echo -e "\n  ${YELLOW}🔓${RESET} Mot de passe maître Bitwarden (essai $attempts/3) :"
    read -s -r BW_PASS </dev/tty
    echo ""
    export BW_PASS
    BW_SESSION=$(bw unlock --raw --passwordenv BW_PASS 2>/dev/null)
    unset BW_PASS

    if [ -n "${BW_SESSION:-}" ]; then
      ok "Bitwarden déverrouillé"
      break
    fi

    error "Mot de passe incorrect."
    if [ "$attempts" -ge 3 ]; then
      warn "3 tentatives échouées — étape clés SSH ignorée, le bootstrap continue."
      return 0
    fi
  done

  # Synchronisation du coffre
  info "Synchronisation du coffre..."
  bw sync &>/dev/null

  # ── Récupération des clés SSH (item de type SSH Key natif Bitwarden) ─────────
  local private_key public_key
  private_key=$(bw get item "$BW_ITEM_SSH_KEY" | jq -r '.sshKey.privateKey // empty')
  public_key=$(bw get item "$BW_ITEM_SSH_KEY" | jq -r '.sshKey.publicKey  // empty')

  if [ -n "$private_key" ]; then
    printf '%s\n' "$private_key" >"$SSH_KEY_PATH"
    printf '%s\n' "$public_key" >"${SSH_KEY_PATH}.pub"
    chmod 600 "$SSH_KEY_PATH"
    chmod 644 "${SSH_KEY_PATH}.pub"
    ok "Clé SSH déployée → $SSH_KEY_PATH"
  else
    warn "Champ sshKey vide pour l'item '${BW_ITEM_SSH_KEY}'."
    warn "Vérifie que l'item est bien de type 'SSH Key' dans Bitwarden."
  fi

  # ── known_hosts : uniquement GitHub ─────────────────────────────────────────
  info "Ajout de github.com aux known_hosts..."
  ssh-keyscan github.com >>"$HOME/.ssh/known_hosts" 2>/dev/null
  chmod 644 "$HOME/.ssh/known_hosts"
  ok "known_hosts mis à jour"

  # ── Verrouillage du coffre ───────────────────────────────────────────────────
  bw lock &>/dev/null || true
  unset BW_SESSION
}

# ─── ÉTAPE 4 : OUTILS ESSENTIELS ─────────────────────────────────────────────
install_tools() {
  step "Installation des outils essentiels"

  _install_zoxide
  _install_lsd
  _install_fzf
  _install_neovim
  _install_zsh_plugins

  ok "Tous les outils sont installés"
}

# ─── ÉTAPE 5 : DOCKER ─────────────────────────────────────────────────────────
install_docker() {
  step "Installation de Docker"

  if has docker; then
    ok "Docker déjà présent ($(docker --version))"
    return
  fi

  case "$DISTRO_FAMILY" in
  arch)
    # Sur Arch, docker est dans les dépôts officiels
    eval "$PKG_INSTALL docker docker-compose" &>/dev/null
    $SUDO systemctl enable --now docker &>/dev/null
    ;;
  debian | fedora)
    # Script officiel Docker — universel Debian/Ubuntu/Fedora/CentOS
    info "Téléchargement du script d'installation officiel Docker..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    info "Lancement de l'installation Docker..."
    $SUDO sh /tmp/get-docker.sh &>/dev/null
    rm -f /tmp/get-docker.sh
    $SUDO systemctl enable --now docker &>/dev/null
    ;;
  *)
    info "Distribution inconnue — tentative avec le script Docker officiel..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    $SUDO sh /tmp/get-docker.sh &>/dev/null
    rm -f /tmp/get-docker.sh
    ;;
  esac

  # Ajout de l'utilisateur au groupe docker (évite $SUDO à chaque commande)
  if getent group docker &>/dev/null; then
    $SUDO usermod -aG docker "$USER"
    warn "Ajouté au groupe 'docker' — effectif à la prochaine connexion SSH"
  fi

  ok "Docker installé ($(docker --version))"
}

_install_zoxide() {
  if has zoxide; then
    ok "zoxide déjà présent"
    return
  fi
  info "Installation de zoxide..."
  case "$DISTRO_FAMILY" in
  arch) eval "$PKG_INSTALL zoxide" &>/dev/null ;;
  fedora) eval "$PKG_INSTALL zoxide" &>/dev/null ;;
  debian)
    # Pas dans les dépôts Debian stable, on utilise le binaire officiel
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash &>/dev/null
    ;;
  *)
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash &>/dev/null
    ;;
  esac
  ok "zoxide installé"
}

_install_lsd() {
  if has lsd; then
    ok "lsd déjà présent"
    return
  fi
  info "Installation de lsd..."
  case "$DISTRO_FAMILY" in
  arch) eval "$PKG_INSTALL lsd" &>/dev/null ;;
  fedora) eval "$PKG_INSTALL lsd" &>/dev/null ;;
  debian)
    # Récupère le dernier .deb depuis GitHub Releases
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
      warn "Impossible de télécharger lsd pour Debian"
    fi
    ;;
  esac
  ok "lsd installé"
}

_install_fzf() {
  if has fzf; then
    ok "fzf déjà présent"
    return
  fi
  info "Installation de fzf..."
  case "$DISTRO_FAMILY" in
  arch) eval "$PKG_INSTALL fzf" &>/dev/null ;;
  fedora) eval "$PKG_INSTALL fzf" &>/dev/null ;;
  debian) eval "$PKG_INSTALL fzf" &>/dev/null ;;
  esac
  ok "fzf installé"
}

_install_neovim() {
  # Vérifie que nvim existe ET fonctionne réellement (AppImage sans FUSE = cassé)
  if has nvim && nvim --version &>/dev/null; then
    ok "neovim déjà présent ($(nvim --version | head -1))"
    _sync_neovim_config
    return
  fi

  if has nvim; then
    warn "neovim trouvé mais non fonctionnel (AppImage sans FUSE ?) — réinstallation..."
    $SUDO rm -f "$(command -v nvim)" 2>/dev/null || true
    $SUDO rm -f /usr/local/bin/nvim 2>/dev/null || true
    $SUDO rm -rf /opt/nvim-linux-x86_64 2>/dev/null || true
  fi

  info "Installation de neovim (tar.gz officiel)..."
  case "$DISTRO_FAMILY" in
  arch)
    eval "$PKG_INSTALL neovim" &>/dev/null
    ;;
  fedora)
    eval "$PKG_INSTALL neovim" &>/dev/null
    ;;
  debian | *)
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz &>/dev/null
    $SUDO rm -rf /opt/nvim-linux-x86_64
    $SUDO tar -C /opt -xzf nvim-linux-x86_64.tar.gz
    rm -f nvim-linux-x86_64.tar.gz
    $SUDO ln -sfn /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
    ;;
  esac
  _sync_neovim_config
  ok "neovim installé"
}

_sync_neovim_config() {
  local nvim_config_dir="$HOME/.config/nvim"
  local nvim_dotfiles_dir="$HOME/.dotfiles-nvim"
  local nvim_repo="git@github.com:WillScarlettOhara/.dotfiles.git"

  # Si la config existe déjà et fonctionne, on met juste à jour
  if [ -d "$nvim_config_dir" ] && [ ! -L "$nvim_config_dir" ]; then
    info "Config neovim déjà présente, pas de remplacement automatique"
    return
  fi

  # On a besoin de la clé SSH pour cloner en git@
  if [ ! -f "$SSH_KEY_PATH" ]; then
    warn "Clé SSH absente — config neovim ignorée (relance après setup Bitwarden)"
    return
  fi

  info "Clonage de la config neovim depuis .dotfiles..."

  # ssh-agent éphémère pour ce clone
  local agent_pid
  eval "$(ssh-agent -s)" &>/dev/null
  agent_pid=$SSH_AGENT_PID
  ssh-add "$SSH_KEY_PATH" &>/dev/null

  # Clone du dépôt principal (sparse : uniquement nvim/.config/nvim)
  if [ -d "$nvim_dotfiles_dir" ]; then
    git -C "$nvim_dotfiles_dir" pull --rebase --quiet 2>/dev/null || true
  else
    git clone --depth=1 --filter=blob:none --sparse \
      "$nvim_repo" "$nvim_dotfiles_dir" &>/dev/null &&
      git -C "$nvim_dotfiles_dir" sparse-checkout set nvim/.config/nvim &>/dev/null
  fi

  # Lien symbolique vers ~/.config/nvim
  local nvim_src="$nvim_dotfiles_dir/nvim/.config/nvim"
  if [ -d "$nvim_src" ]; then
    mkdir -p "$HOME/.config"
    ln -sfn "$nvim_src" "$nvim_config_dir"
    ok "Config neovim liée → $nvim_config_dir"
  else
    warn "Dossier nvim/.config/nvim introuvable dans le dépôt .dotfiles"
  fi

  # Arrêt de l'agent éphémère
  kill "$agent_pid" &>/dev/null || true
}

_install_zsh_plugins() {
  # Zinit (gestionnaire de plugins zsh)
  local ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
  if [ ! -d "$ZINIT_HOME" ]; then
    info "Installation de zinit..."
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME" &>/dev/null
    ok "zinit installé"
  else
    ok "zinit déjà présent"
  fi
}

# ─── ÉTAPE 6 : DOTFILES SSH ───────────────────────────────────────────────────
setup_dotfiles() {
  step "Récupération des dotfiles SSH"

  if [ -d "$DOTFILES_DIR" ]; then
    info "Mise à jour du dépôt dotfiles existant..."
    git -C "$DOTFILES_DIR" pull --rebase --quiet 2>/dev/null || warn "Impossible de mettre à jour les dotfiles"
  else
    info "Clonage de $DOTFILES_REPO..."
    git clone --depth=1 "$DOTFILES_REPO" "$DOTFILES_DIR" 2>/dev/null || {
      error "Impossible de cloner le dépôt. Vérifie l'URL dans DOTFILES_REPO."
      return 1
    }
  fi

  # Stow ou liens symboliques manuels
  if has stow; then
    info "Application via GNU Stow..."
    cd "$DOTFILES_DIR"
    stow --restow --target="$HOME" . 2>/dev/null || warn "stow a rencontré un conflit (fichiers existants)"
  else
    _manual_link_dotfiles
  fi

  ok "Dotfiles SSH appliqués → $DOTFILES_DIR"
}

_manual_link_dotfiles() {
  # Fichiers à lier (src dans DOTFILES_DIR → dst dans HOME)
  # Note : le repo stocke 'zshrc' sans point, on le lie vers ~/.zshrc
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
        warn "Backup créé : ${dst}.bak.*"
      fi
      ln -sfn "$src" "$dst"
      info "Lié : $src_name → $dst"
    fi
  done
}

# ─── ÉTAPE 7 : ZSH PAR DÉFAUT ────────────────────────────────────────────────
set_default_shell() {
  step "Configuration de zsh comme shell par défaut"

  local zsh_path
  zsh_path=$(which zsh 2>/dev/null || true)

  if [ -z "$zsh_path" ]; then
    warn "zsh introuvable, impossible de le définir comme shell par défaut"
    return
  fi

  if [ "$SHELL" = "$zsh_path" ]; then
    ok "zsh est déjà le shell par défaut"
    return
  fi

  # Ajout à /etc/shells si nécessaire
  if ! grep -q "$zsh_path" /etc/shells 2>/dev/null; then
    echo "$zsh_path" | $SUDO tee -a /etc/shells &>/dev/null
  fi

  if chsh -s "$zsh_path" "$USER" 2>/dev/null; then
    ok "zsh défini comme shell par défaut (effectif à la prochaine connexion)"
  else
    warn "chsh a échoué. Lance manuellement : chsh -s $zsh_path"
  fi
}

# ─── RÉSUMÉ FINAL ─────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${GREEN}║              Bootstrap terminé avec succès !             ║${RESET}"
  echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  ${BOLD}Prochaines étapes :${RESET}"
  echo -e "  ${CYAN}1.${RESET} Lance ${BOLD}zsh${RESET} ou ouvre une nouvelle session SSH"
  echo -e "  ${CYAN}2.${RESET} Déconnecte/reconnecte ta session (droits groupe docker)"
  echo -e "  ${CYAN}3.${RESET} Vérifie ta clé SSH : ${BOLD}ls -la ~/.ssh/${RESET}"
  echo -e "  ${CYAN}4.${RESET} Édite ${BOLD}~/.dotfiles-ssh/.zshrc${RESET} si tu veux personnaliser"
  echo ""
  echo -e "  ${DIM}Dotfiles : $DOTFILES_DIR${RESET}"
  echo -e "  ${DIM}Session Bitwarden : fermée${RESET}"
  echo ""
}

# ─── MENU INTERACTIF ──────────────────────────────────────────────────────────
run_interactive() {
  banner
  detect_distro
  echo ""

  echo -e "${BOLD}Que veux-tu installer ?${RESET}"
  echo -e "  ${CYAN}[1]${RESET} Tout (recommandé)"
  echo -e "  ${CYAN}[2]${RESET} Paquets + outils seulement (sans Bitwarden)"
  echo -e "  ${CYAN}[3]${RESET} Bitwarden + clés SSH seulement"
  echo -e "  ${CYAN}[4]${RESET} Dotfiles seulement"
  echo -e "  ${CYAN}[5]${RESET} Docker seulement"
  echo -e "  ${CYAN}[q]${RESET} Quitter"
  echo ""
  read -rp "  Choix [1]: " choice
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
    detect_distro 2>/dev/null || true
    install_docker
    ;;
  q | Q)
    echo "Au revoir !"
    exit 0
    ;;
  *)
    warn "Choix invalide, installation complète par défaut"
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

# ─── POINT D'ENTRÉE ───────────────────────────────────────────────────────────
# Mode non-interactif si lancé via pipe (curl | bash) → tout installer
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
