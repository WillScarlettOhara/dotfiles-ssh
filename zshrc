# ══════════════════════════════════════════════════════════════════════════════
#  ~/.zshrc — Configuration SSH légère (sans p10k, sans tmux, sans ghostty)
#  Inspirée du zshrc host : fzf, autocomplétion, vi-mode, aliases, zoxide
# ══════════════════════════════════════════════════════════════════════════════

# ─── ZINIT ────────────────────────────────────────────────────────────────────
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ -d "$ZINIT_HOME" ]; then
  source "${ZINIT_HOME}/zinit.zsh"
else
  echo "[zshrc] ⚠  zinit non trouvé — lance bootstrap-ssh.sh"
fi

# ─── PROMPT MINIMALISTE (remplace p10k) ───────────────────────────────────────
# Prompt propre, coloré, avec infos git — sans dépendances
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats ' %F{yellow}(%b)%f'
zstyle ':vcs_info:*' enable git

setopt PROMPT_SUBST
PROMPT='%F{blue}%n%f%F{white}@%f%F{cyan}%m%f %F{green}%~%f${vcs_info_msg_0_} %F{white}%(!.#.❯)%f '

# ─── PLUGINS ZINIT ───────────────────────────────────────────────────────────
# (chargés seulement si zinit est disponible)
if (( ${+functions[zinit]} )); then
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#665c54"

  zinit light zsh-users/zsh-syntax-highlighting
  zinit light zsh-users/zsh-completions
  zinit light zsh-users/zsh-autosuggestions
  zinit light Aloxaf/fzf-tab

  # Snippets Oh-My-Zsh utiles en SSH
  zinit snippet OMZL::git.zsh
  zinit snippet OMZP::git
  zinit snippet OMZP::sudo
  zinit snippet OMZP::command-not-found
fi

# ─── COMPLÉTION ───────────────────────────────────────────────────────────────
autoload -Uz compinit && compinit
(( ${+functions[zinit]} )) && zinit cdreplay -q

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# ─── KEYBINDINGS ──────────────────────────────────────────────────────────────
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^e' edit-command-line
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region

# ─── HISTORIQUE ───────────────────────────────────────────────────────────────
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory sharehistory hist_ignore_space hist_ignore_all_dups \
       hist_save_no_dups hist_ignore_dups hist_find_no_dups

# ─── VI MODE ──────────────────────────────────────────────────────────────────
function zvm_config() {
  ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT
  ZVM_VI_INSERT_ESCAPE_BINDKEY=jj
  ZVM_CURSOR_STYLE_ENABLED=true
}
(( ${+functions[zinit]} )) && zinit light jeffreytse/zsh-vi-mode

# ─── FZF ──────────────────────────────────────────────────────────────────────
if command -v fzf &>/dev/null; then
  eval "$(fzf --zsh)"
  export FZF_DEFAULT_OPTS='
    --color=bg+:#3c3836,bg:#282828,spinner:#fb4934,hl:#928374,fg:#ebdbb2,header:#928374
    --color=info:#8ec07c,pointer:#fb4934,marker:#fb4934,fg+:#ebdbb2,prompt:#fb4934,hl+:#fb4934
    --height=50% --border=rounded --layout=reverse --prompt="❯ " --pointer="▶"
  '
fi

# ─── ZOXIDE ───────────────────────────────────────────────────────────────────
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init --cmd cd zsh)"
fi

# ─── ALIASES ──────────────────────────────────────────────────────────────────
# Navigation & listing
if command -v lsd &>/dev/null; then
  alias l='lsd -l'
  alias la='lsd -a'
  alias lla='lsd -la'
  alias lt='lsd --tree'
else
  alias l='ls -lh --color=auto'
  alias la='ls -lah --color=auto'
  alias lla='ls -lah --color=auto'
  alias lt='find . -maxdepth 3 | sort'
fi

# Neovim ou fallback vim
if command -v nvim &>/dev/null; then
  alias vim='nvim'
  alias vi='nvim'
fi

# Sécurité & defaults
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -p'
alias c='clear'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

# Réseau
alias ports='sudo lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null || sudo ss -tlnp'
alias myip='curl -s ifconfig.me'
alias path='echo -e ${PATH//:/\\n}'

# Git (complément des aliases OMZ)
alias gundo='git reset --soft HEAD~1'
alias glog='git log --graph --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset" --abbrev-commit'

# SSH : gestion rapide des clés
alias ssh-add-key='eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519'

# Détection gestionnaire de paquets
if command -v pacman &>/dev/null;  then alias update='sudo pacman -Syu'
elif command -v dnf &>/dev/null;   then alias update='sudo dnf upgrade -y'
elif command -v apt-get &>/dev/null; then alias update='sudo apt-get update && sudo apt-get upgrade -y'
fi

# ─── EXPORTS ──────────────────────────────────────────────────────────────────
export EDITOR="nvim"
export VISUAL="nvim"
export PATH="$HOME/.local/bin:$PATH"

export LS_COLORS="*.lua=38;5;214:*.rs=38;5;167:*.py=38;5;109:*.md=38;5;108:*.toml=38;5;175:*.json=38;5;214:*.yaml=38;5;109:*.yml=38;5;109:*.sh=38;5;142:*.zsh=38;5;142:*.fish=38;5;142:*.js=38;5;214:*.ts=38;5;109:*.jsx=38;5;214:*.tsx=38;5;109:*.html=38;5;167:*.css=38;5;109:*.scss=38;5;175:*.go=38;5;109:*.php=38;5;175:*.rb=38;5;167:*.sql=38;5;108:*.vim=38;5;142:*.conf=38;5;246:*.env=38;5;214:*.lock=38;5;239:*.log=38;5;239:*.png=38;5;108:*.jpg=38;5;108:*.gif=38;5;108:*.svg=38;5;108:*.pdf=38;5;167:*.zip=38;5;175:*.tar=38;5;175:*.gz=38;5;175:"

# ─── ACCUEIL ──────────────────────────────────────────────────────────────────
# Affiche un mini résumé à la connexion
echo ""
echo "  \033[1;34m$(hostname)\033[0m — \033[2m$(uname -sr)\033[0m — \033[32m$(uptime -p 2>/dev/null || uptime)\033[0m"
echo "  \033[2mShell : zsh $(zsh --version | cut -d' ' -f2)  •  Éditeur : ${EDITOR}  •  $(date '+%A %d %B %Y')\033[0m"
echo ""
