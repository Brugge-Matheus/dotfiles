#!/usr/bin/env bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log_info() { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
log_ok() { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
log_warn() { printf "\033[1;33m[WARN]\033[0m  %s\n" "$1"; }
log_err() { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1"; }

# ---------------------------------------------------------------------------
# Detect OS
# ---------------------------------------------------------------------------
OS=""
DISTRO=""

case "$(uname -s)" in
Linux)
  OS="linux"
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO="$ID"
  fi
  ;;
Darwin)
  OS="macos"
  ;;
*)
  log_err "Sistema operacional não suportado: $(uname -s)"
  log_err "Este script suporta apenas macOS e Linux."
  exit 1
  ;;
esac

log_info "Sistema detectado: $OS ${DISTRO:+($DISTRO)}"

# ---------------------------------------------------------------------------
# macOS — Homebrew
# ---------------------------------------------------------------------------
install_macos_deps() {
  log_info "Verificando Homebrew..."
  if ! command -v brew &>/dev/null; then
    log_info "Instalando Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null ||
      eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null
  else
    log_ok "Homebrew já instalado. Atualizando..."
    brew update
  fi

  log_info "Instalando pacotes via Homebrew..."
  BREW_PACKAGES=(
    zsh tmux neovim starship fzf ripgrep
    coreutils gnu-sed gawk tree wget curl git
    lazygit fd bat
  )

  for pkg in "${BREW_PACKAGES[@]}"; do
    if brew list "$pkg" &>/dev/null; then
      log_ok "$pkg já instalado."
    else
      log_info "Instalando $pkg..."
      brew install "$pkg"
    fi
  done
}

# ---------------------------------------------------------------------------
# Linux — apt (Ubuntu/Debian) ou genérico
# ---------------------------------------------------------------------------
install_linux_deps() {
  log_info "Atualizando pacotes..."
  sudo apt-get update -y
  sudo apt-get upgrade -y

  log_info "Instalando dependências base..."
  sudo apt-get install -y \
    zsh tmux git curl wget unzip build-essential \
    fzf ripgrep tree bat fd-find \
    gettext cmake ninja-build pkg-config libtool libtool-bin \
    autoconf automake lua5.4 liblua5.4-dev luarocks \
    fonts-firacode fonts-jetbrains-mono

  # Neovim: tenta instalar versão recente via snap, senão compila
  if ! command -v nvim &>/dev/null; then
    log_info "Instalando Neovim..."
    if command -v snap &>/dev/null; then
      sudo snap install nvim --classic
    else
      log_info "Compilando Neovim a partir do source..."
      git clone https://github.com/neovim/neovim.git /tmp/neovim
      cd /tmp/neovim
      git checkout stable
      make CMAKE_BUILD_TYPE=Release
      sudo make install
      cd ~
      rm -rf /tmp/neovim
    fi
  else
    log_ok "Neovim já instalado: $(nvim --version | head -1)"
  fi

  # Starship
  if ! command -v starship &>/dev/null; then
    log_info "Instalando Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
  else
    log_ok "Starship já instalado."
  fi

  # lazygit
  if ! command -v lazygit &>/dev/null; then
    log_info "Instalando lazygit..."
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
    curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar -xf /tmp/lazygit.tar.gz -C /tmp lazygit
    sudo install /tmp/lazygit /usr/local/bin
    rm -f /tmp/lazygit.tar.gz /tmp/lazygit
  else
    log_ok "lazygit já instalado."
  fi
}

# ---------------------------------------------------------------------------
# Instala dependências de acordo com o OS
# ---------------------------------------------------------------------------
if [ "$OS" = "macos" ]; then
  install_macos_deps
elif [ "$OS" = "linux" ]; then
  install_linux_deps
fi

# ---------------------------------------------------------------------------
# Zsh plugins
# ---------------------------------------------------------------------------
ZSH_PLUGIN_DIR="$HOME/.zsh"
mkdir -p "$ZSH_PLUGIN_DIR"

log_info "Instalando plugins do Zsh..."

if [ ! -d "$ZSH_PLUGIN_DIR/zsh-autosuggestions" ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_PLUGIN_DIR/zsh-autosuggestions"
  log_ok "zsh-autosuggestions instalado."
else
  log_ok "zsh-autosuggestions já existe."
fi

if [ ! -d "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting" ]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting"
  log_ok "zsh-syntax-highlighting instalado."
else
  log_ok "zsh-syntax-highlighting já existe."
fi

# ---------------------------------------------------------------------------
# TPM — Tmux Plugin Manager
# ---------------------------------------------------------------------------
log_info "Verificando TPM (Tmux Plugin Manager)..."
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  log_ok "TPM instalado."
else
  log_ok "TPM já existe."
fi

# ---------------------------------------------------------------------------
# Symlinks
# ---------------------------------------------------------------------------
log_info "Criando symlinks..."

safe_link() {
  local src="$1"
  local dst="$2"
  local dst_dir
  dst_dir="$(dirname "$dst")"

  mkdir -p "$dst_dir"

  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -e "$dst" ]; then
    log_warn "Backup: $dst -> ${dst}.bak"
    mv "$dst" "${dst}.bak"
  fi

  ln -sf "$src" "$dst"
  log_ok "  $src -> $dst"
}

# Zsh
safe_link "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"

# Starship
safe_link "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"

# Tmux
safe_link "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
mkdir -p "$HOME/.tmux/scripts"
for script in "$DOTFILES_DIR/tmux/scripts/"*.sh; do
  safe_link "$script" "$HOME/.tmux/scripts/$(basename "$script")"
  chmod +x "$script"
done

# Neovim
safe_link "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"

# Git
safe_link "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"

# ---------------------------------------------------------------------------
# Mudar shell padrão para zsh (se necessário)
# ---------------------------------------------------------------------------
if [ "$SHELL" != "$(command -v zsh)" ]; then
  log_info "Alterando shell padrão para zsh..."
  ZSH_PATH="$(command -v zsh)"
  if ! grep -qF "$ZSH_PATH" /etc/shells; then
    echo "$ZSH_PATH" | sudo tee -a /etc/shells
  fi
  chsh -s "$ZSH_PATH"
  log_ok "Shell padrão alterado para zsh."
fi

# ---------------------------------------------------------------------------
# Finalização
# ---------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_ok "Setup concluído!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Próximos passos manuais (abra um novo terminal):"
echo ""
echo "  1. Abra o Neovim:  nvim"
echo "     O Lazy.nvim vai instalar todos os plugins automaticamente."
echo ""
echo "  2. Abra o Tmux e pressione:  Ctrl+b + I"
echo "     Para instalar os plugins do TPM."
echo ""
echo "  3. Se quiser configs específicas desta máquina (Herd, conda, etc.):"
echo "     Crie o arquivo ~/.zshrc.local — ele é carregado pelo .zshrc"
echo "     mas NÃO está no repositório."
echo ""
echo "  4. Reinicie o terminal."
echo ""
