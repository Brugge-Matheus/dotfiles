#!/usr/bin/env bash

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERRORS=()

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
  sudo apt-get update -y || ERRORS+=("apt-get update falhou")

  log_info "Instalando dependências base..."
  sudo apt-get install -y \
    zsh tmux git curl wget unzip build-essential \
    fzf ripgrep tree gettext \
    cmake ninja-build pkg-config libtool libtool-bin \
    autoconf automake luarocks \
    fonts-firacode fonts-jetbrains-mono 2>/dev/null || \
  sudo apt-get install -y \
    zsh tmux git curl wget unzip build-essential \
    fzf ripgrep tree gettext \
    cmake ninja-build pkg-config libtool libtool-bin \
    autoconf automake luarocks || \
    ERRORS+=("Alguns pacotes apt falharam — verifique manualmente")

  # bat (pode ser batcat no Ubuntu)
  if ! command -v bat &>/dev/null && ! command -v batcat &>/dev/null; then
    sudo apt-get install -y bat 2>/dev/null || sudo apt-get install -y batcat 2>/dev/null || true
  fi

  # fd
  if ! command -v fd &>/dev/null; then
    sudo apt-get install -y fd-find 2>/dev/null && \
      ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd" 2>/dev/null || true
  fi

  # Neovim: baixa binário pré-compilado do GitHub (mais confiável que snap ou compilar)
  if ! command -v nvim &>/dev/null; then
    log_info "Instalando Neovim (binário pré-compilado)..."
    NVIM_URL="https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.tar.gz"
    curl -Lo /tmp/nvim.tar.gz "$NVIM_URL" && \
      sudo tar -xzf /tmp/nvim.tar.gz -C /opt && \
      sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim && \
      rm -f /tmp/nvim.tar.gz && \
      log_ok "Neovim instalado: $(nvim --version | head -1)" || \
      ERRORS+=("Falha ao instalar Neovim — instale manualmente")
  else
    log_ok "Neovim já instalado: $(nvim --version | head -1)"
  fi

  # Starship
  if ! command -v starship &>/dev/null; then
    log_info "Instalando Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes || \
      ERRORS+=("Falha ao instalar Starship")
  else
    log_ok "Starship já instalado."
  fi

  # lazygit
  if ! command -v lazygit &>/dev/null; then
    log_info "Instalando lazygit..."
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
      | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
    if [ -n "$LAZYGIT_VERSION" ]; then
      ARCH="$(uname -m)"
      [ "$ARCH" = "aarch64" ] && LG_ARCH="arm64" || LG_ARCH="x86_64"
      curl -Lo /tmp/lazygit.tar.gz \
        "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_${LG_ARCH}.tar.gz" && \
        tar -xf /tmp/lazygit.tar.gz -C /tmp lazygit && \
        sudo install /tmp/lazygit /usr/local/bin && \
        rm -f /tmp/lazygit.tar.gz /tmp/lazygit && \
        log_ok "lazygit instalado." || \
        ERRORS+=("Falha ao instalar lazygit")
    fi
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

  if [ ! -e "$src" ]; then
    log_err "Origem não encontrada, pulando: $src"
    ERRORS+=("Symlink ignorado — origem não existe: $src")
    return 1
  fi

  mkdir -p "$dst_dir"

  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -e "$dst" ]; then
    log_warn "Backup: $dst -> ${dst}.bak"
    mv "$dst" "${dst}.bak"
  fi

  ln -sf "$src" "$dst"

  if [ -L "$dst" ]; then
    log_ok "Linked: $dst -> $src"
  else
    log_err "Falhou ao criar symlink: $dst"
    ERRORS+=("Falha no symlink: $dst -> $src")
  fi
}

# Zsh
safe_link "$DOTFILES_DIR/zsh/.zshrc"             "$HOME/.zshrc"

# Starship
safe_link "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"

# Tmux
safe_link "$DOTFILES_DIR/tmux/.tmux.conf"        "$HOME/.tmux.conf"
mkdir -p "$HOME/.tmux/scripts"
for script in "$DOTFILES_DIR/tmux/scripts/"*.sh; do
  [ -f "$script" ] || continue
  safe_link "$script" "$HOME/.tmux/scripts/$(basename "$script")"
  chmod +x "$script"
done

# Neovim
safe_link "$DOTFILES_DIR/nvim"                   "$HOME/.config/nvim"

# Git
safe_link "$DOTFILES_DIR/git/.gitconfig"         "$HOME/.gitconfig"

# ---------------------------------------------------------------------------
# Verificação dos symlinks criados
# ---------------------------------------------------------------------------
echo ""
log_info "Verificando symlinks criados:"
LINKS=(
  "$HOME/.zshrc"
  "$HOME/.config/starship.toml"
  "$HOME/.tmux.conf"
  "$HOME/.config/nvim"
  "$HOME/.gitconfig"
)
for link in "${LINKS[@]}"; do
  if [ -L "$link" ]; then
    printf "  \033[1;32m✔\033[0m  %s -> %s\n" "$link" "$(readlink "$link")"
  else
    printf "  \033[1;31m✘\033[0m  %s  (NÃO criado)\n" "$link"
    ERRORS+=("Symlink não criado: $link")
  fi
done

# ---------------------------------------------------------------------------
# Mudar shell padrão para zsh (se necessário)
# ---------------------------------------------------------------------------
if command -v zsh &>/dev/null; then
  ZSH_PATH="$(command -v zsh)"
  if [ "$SHELL" != "$ZSH_PATH" ]; then
    log_info "Alterando shell padrão para zsh..."
    if ! grep -qF "$ZSH_PATH" /etc/shells; then
      echo "$ZSH_PATH" | sudo tee -a /etc/shells
    fi
    chsh -s "$ZSH_PATH" || ERRORS+=("Falha ao alterar shell para zsh — rode: chsh -s $(command -v zsh)")
    log_ok "Shell padrão alterado para zsh."
  fi
else
  ERRORS+=("zsh não encontrado — instale manualmente e rode: chsh -s \$(which zsh)")
fi

# ---------------------------------------------------------------------------
# Finalização
# ---------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_ok "Setup concluído!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""
  log_warn "Itens que precisam de atenção manual:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
fi

echo ""
echo "Próximos passos (abra um novo terminal):"
echo ""
echo "  1. Abra o Neovim:  nvim"
echo "     O Lazy.nvim instalará todos os plugins automaticamente."
echo ""
echo "  2. Abra o Tmux e pressione:  Ctrl+b + I"
echo "     Para instalar os plugins do TPM."
echo ""
echo "  3. Configs específicas desta máquina (Herd, conda, etc.):"
echo "     Crie ~/.zshrc.local — é carregado pelo .zshrc mas não está no repo."
echo ""
echo "  4. Reinicie o terminal."
echo ""
