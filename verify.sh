#!/usr/bin/env bash

# Script de verificação pós-instalação
# Execute após rodar setup.sh e recarregar o shell

echo "🔍 Verificando instalação dos dotfiles..."
echo ""

ERRORS=0

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check() {
  local name="$1"
  local cmd="$2"
  
  if eval "$cmd" &>/dev/null; then
    echo -e "${GREEN}✅${NC} $name"
  else
    echo -e "${RED}❌${NC} $name"
    ((ERRORS++))
  fi
}

check_version() {
  local name="$1"
  local cmd="$2"
  
  if command -v "$cmd" &>/dev/null; then
    version=$("$cmd" --version 2>&1 | head -1)
    echo -e "${GREEN}✅${NC} $name: $version"
  else
    echo -e "${RED}❌${NC} $name: não encontrado"
    ((ERRORS++))
  fi
}

check_symlink() {
  local name="$1"
  local path="$2"
  
  if [ -L "$path" ]; then
    target=$(readlink "$path")
    echo -e "${GREEN}✅${NC} $name: $path -> $target"
  else
    echo -e "${RED}❌${NC} $name: $path (não é symlink)"
    ((ERRORS++))
  fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Ferramentas do Sistema"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_version "Zsh" "zsh"
check_version "Tmux" "tmux"
check_version "Neovim" "nvim"
check_version "Git" "git"
check_version "Starship" "starship"
check_version "fzf" "fzf"
check_version "ripgrep" "rg"
check "fd" "command -v fd"
check "bat" "command -v bat || command -v batcat"
check "lazygit" "command -v lazygit"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 asdf"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_version "asdf" "asdf"

if command -v asdf &>/dev/null; then
  echo ""
  echo "Versões instaladas:"
  asdf current 2>/dev/null || echo "  Nenhuma versão instalada ainda"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Linguagens (via asdf)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_version "Node.js" "node"
check_version "npm" "npm"
check_version "Python" "python"
check_version "pip" "pip"
check_version "Ruby" "ruby"
check_version "gem" "gem"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔗 Symlinks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_symlink "Zsh config" "$HOME/.zshrc"
check_symlink "Starship config" "$HOME/.config/starship.toml"
check_symlink "Tmux config" "$HOME/.tmux.conf"
check_symlink "Neovim config" "$HOME/.config/nvim"
check_symlink "Git config" "$HOME/.gitconfig"
check_symlink "Ghostty config" "$HOME/.config/ghostty/config"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧩 Plugins"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check "zsh-autosuggestions" "[ -d $HOME/.zsh/zsh-autosuggestions ]"
check "zsh-syntax-highlighting" "[ -d $HOME/.zsh/zsh-syntax-highlighting ]"
check "TPM (Tmux Plugin Manager)" "[ -d $HOME/.tmux/plugins/tpm ]"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🐍 Pacotes Python"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v pip &>/dev/null; then
  if pip show pynvim &>/dev/null; then
    echo -e "${GREEN}✅${NC} pynvim instalado"
  else
    echo -e "${RED}❌${NC} pynvim NÃO instalado (execute: pip install pynvim)"
    ((ERRORS++))
  fi
else
  echo -e "${YELLOW}⚠️${NC}  pip não encontrado"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💎 Gems Ruby"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v gem &>/dev/null; then
  if gem list | grep -q "^neovim "; then
    echo -e "${GREEN}✅${NC} gem neovim instalado"
  else
    echo -e "${RED}❌${NC} gem neovim NÃO instalado (execute: gem install neovim)"
    ((ERRORS++))
  fi
else
  echo -e "${YELLOW}⚠️${NC}  gem não encontrado"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Shell"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$SHELL" = "$(command -v zsh)" ]; then
  echo -e "${GREEN}✅${NC} Shell padrão: $SHELL"
else
  echo -e "${YELLOW}⚠️${NC}  Shell padrão: $SHELL (deveria ser zsh)"
  echo "    Execute: chsh -s \$(which zsh)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ERRORS -eq 0 ]; then
  echo -e "${GREEN}✨ Instalação completa! Tudo funcionando.${NC}"
  echo ""
  echo "Próximos passos:"
  echo "  1. Abra o Neovim: nvim"
  echo "     (Lazy.nvim instalará plugins automaticamente)"
  echo ""
  echo "  2. Abra o Tmux e pressione: Ctrl+b + I"
  echo "     (Para instalar plugins do TPM)"
  echo ""
  echo "  3. Crie ~/.zshrc.local para configs específicas desta máquina"
else
  echo -e "${RED}❌ Encontrados $ERRORS problemas.${NC}"
  echo ""
  echo "Sugestões:"
  echo "  - Execute: exec zsh -l"
  echo "  - Verifique erros no setup.sh"
  echo "  - Rode: asdf reshim"
  echo "  - Veja: ~/.zshrc para verificar se asdf está carregado"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
