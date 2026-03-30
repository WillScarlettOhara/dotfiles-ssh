# dotfiles-ssh

> Environnement de travail SSH déployé en une commande.

## Démarrage rapide

```bash
# Sur la machine distante :
curl -fsSL https://raw.githubusercontent.com/WillScarlettOhara/dotfiles-ssh/main/bootstrap-ssh.sh | bash
# — ou —
bash <(curl -fsSL https://raw.githubusercontent.com/WillScarlettOhara/dotfiles-ssh/main/bootstrap-ssh.sh)
```

---

## Ce que fait le script

| Étape                   | Description                                             |
| ----------------------- | ------------------------------------------------------- |
| **1. Détection distro** | Arch · Fedora · Debian/Ubuntu                           |
| **2. Paquets de base**  | `curl git wget zsh build-essential …`                   |
| **3. Bitwarden CLI**    | Via `paru/yay` (Arch) ou `npm` (autres)                 |
| **4. Clés SSH**         | Récupérées depuis ton coffre Bitwarden (pièces jointes) |
| **5. Outils**           | `zoxide lsd fzf neovim zinit`                           |
| **6. Dotfiles**         | Clone ce dépôt + liens symboliques vers `~`             |
| **7. Shell**            | zsh défini comme shell par défaut (`chsh`)              |

---

## Structure du dépôt

```
dotfiles-ssh/
├── bootstrap-ssh.sh      ← Script principal
├── .zshrc                ← Config zsh allégée (pas de p10k, pas de tmux)
├── .gitconfig            ← (optionnel) ta config git
├── .gitignore_global     ← (optionnel)
└── nvim/                 ← (optionnel) config neovim minimale pour SSH
    └── init.lua
```

---

## Configuration Bitwarden : préparer ses clés SSH

Dans ton coffre Bitwarden, crée un **Login** nommé exactement `ssh-perso` (ou change `BW_ITEM_SSH_KEY` dans le script).

Attache-y deux fichiers :

- `id_ed25519` — ta clé privée
- `id_ed25519.pub` — ta clé publique

```
Bitwarden > Nouvel élément > Login
  Nom        : ssh-perso
  Pièces jointes : id_ed25519  +  id_ed25519.pub
```

---

## Variables à personnaliser

En haut de `bootstrap-ssh.sh` :

```bash
DOTFILES_REPO="https://github.com/TON_USER/dotfiles-ssh"  # URL de ce dépôt
BW_ITEM_SSH_KEY="ssh-perso"                                # Nom de l'item Bitwarden
SSH_KEY_PATH="$HOME/.ssh/id_ed25519"                       # Destination de la clé
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
