# dotfiles-ssh

> Environnement de travail SSH déployé en une commande.

## Démarrage rapide

### Linux / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/WillScarlettOhara/dotfiles-ssh/main/bootstrap-ssh.sh | bash
```

### Windows (PowerShell 5.1+)

```powershell
irm https://raw.githubusercontent.com/WillScarlettOhara/dotfiles-ssh/main/bootstrap-win.ps1 | iex
# — ou par étape —
powershell -ExecutionPolicy Bypass -File .\bootstrap-win.ps1 -Stage Bitwarden
```

---

## Ce que fait le script

| Étape                   | Description                                             |
| ----------------------- | ------------------------------------------------------- |
| **1. Détection distro** | Arch · Fedora · Debian/Ubuntu                           |
| **2. Paquets de base**  | `curl git wget zsh build-essential …`                  |
| **3. Bitwarden CLI**    | Téléchargement du binaire officiel + Node.js via NVM    |
| **4. Clés SSH**         | Récupérées depuis ton coffre Bitwarden (type SSH Key)   |
| **5. Git config**       | Identité GitHub noreply (ne remplace pas si existante)   |
| **6. Outils**           | `zoxide lsd fzf neovim lazygit zinit`                   |
| **7. Docker**           | Via paquets (Arch) ou script officiel (Debian/Fedora)   |
| **8. Dotfiles**         | Clone ce dépôt + liens symboliques vers `~`             |
| **9. Shell**            | zsh défini comme shell par défaut (`chsh`)               |
| **10. SSH daemon**      | Hardening : clé uniquement, pas de mot de passe         |

---

## Structure du dépôt

```
dotfiles-ssh/
├── bootstrap-ssh.sh      ← Script Linux/WSL
├── bootstrap-win.ps1     ← Script Windows
├── zshrc                 ← Config zsh allégée (pas de p10k, pas de tmux)
├── .gitconfig            ← Config git (identité noreply)
└── README.md
```

Les fichiers sont liés symboliquement via `_link_dotfiles()` :
- `zshrc` → `~/.zshrc`
- `.gitconfig` → `~/.gitconfig`

---

## Configuration Bitwarden : préparer ses clés SSH

Dans ton coffre Bitwarden, crée un élément de type **SSH Key** nommé exactement `SSH GitHub` (ou change `BW_ITEM_SSH_KEY` / `BwItemSshKey` dans le script).

```
Bitwarden > Nouvel élément > SSH Key
  Nom        : SSH GitHub
  Clé privée : (coller le contenu de id_ed25519)
  Clé publique : (coller le contenu de id_ed25519.pub)
```

---

## Variables à personnaliser

En haut de `bootstrap-ssh.sh` :

```bash
DOTFILES_REPO="https://github.com/TON_USER/dotfiles-ssh"  # URL de ce dépôt
BW_ITEM_SSH_KEY="SSH GitHub"                               # Nom de l'item Bitwarden
SSH_KEY_PATH="$HOME/.ssh/id_ed25519"                       # Destination de la clé
NVM_VERSION="v0.40.4"                                      # Version NVM
NODE_VERSION="24"                                          # Version Node.js via NVM
```

En haut de `bootstrap-win.ps1` :

```powershell
$Config = @{
    DotfilesRepo = 'https://github.com/TON_USER/dotfiles-ssh'
    SshKeyPath   = Join-Path $env:USERPROFILE '.ssh\id_ed25519'
    BwItemSshKey = 'SSH GitHub'
    # ...
}
```

---

## Mode interactif vs pipe

| Lancement               | Comportement                       |
| ----------------------- | ---------------------------------- |
| `bash bootstrap-ssh.sh` | Menu interactif (choix des étapes) |
| `curl … \| bash`        | Installation complète automatique  |

---

## Ce qui n'est PAS synchronisé (géré sur l'hôte uniquement)

- `~/.p10k.zsh` et Powerlevel10k
- Config tmux
- Config Ghostty
- Fonts Nerd Fonts (non disponibles sur serveur headless)

Le prompt SSH utilise un prompt git natif zsh (`vcs_info`) — rapide, sans dépendances.

---

## Mise à jour des dotfiles sur une machine existante

```bash
cd ~/.dotfiles-ssh && git pull
# Les liens symboliques pointent déjà vers ce dossier, rien d'autre à faire.
```