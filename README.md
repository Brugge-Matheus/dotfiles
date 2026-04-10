# Dotfiles

Configuração completa do ambiente de desenvolvimento com Zsh, Neovim, Tmux, Starship e mais.

## 🚀 Instalação Rápida

```bash
git clone https://github.com/seu-usuario/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash setup.sh
```

Após a instalação:
```bash
exec zsh -l
```

## 📦 O que está incluído

- **Zsh**: Shell com plugins (autosuggestions, syntax-highlighting)
- **Neovim**: Editor com Lazy.nvim e LSP servers via Mason
- **Tmux**: Terminal multiplexer com TPM
- **Starship**: Prompt personalizado
- **asdf**: Gerenciador de versões para Node.js, Python, Ruby
- **Git**: Configurações globais

## 🛠️ Ferramentas instaladas via asdf

O script usa [asdf](https://asdf-vm.com/) para gerenciar as seguintes ferramentas:

- **Node.js** (LTS): Para LSP servers (typescript-language-server, copilot, etc.)
- **Python** (3.12.7): Para LSP servers (pyright, ruff) e plugins nvim
- **Ruby** (3.3.6): Para projetos Rails

### Gerenciar versões

```bash
# Listar versões instaladas
asdf current

# Instalar versão específica
asdf install nodejs 20.11.0
asdf install python 3.11.8
asdf install ruby 3.2.3

# Definir versão global
asdf global nodejs 20.11.0

# Definir versão local (no diretório do projeto)
asdf local python 3.11.8
```

## 📁 Estrutura

```
dotfiles/
├── setup.sh           # Script de instalação
├── .tool-versions     # Versões globais do asdf
├── zsh/
│   └── .zshrc        # Configuração do Zsh
├── nvim/             # Neovim config (Lazy.nvim)
├── tmux/             # Tmux config
├── starship/         # Starship prompt
└── git/              # Git config
```

## 🔧 Neovim

O Neovim usa [Lazy.nvim](https://github.com/folke/lazy.nvim) para gerenciar plugins.

Ao abrir o Neovim pela primeira vez:
```bash
nvim
```

Os plugins serão instalados automaticamente. O Mason instalará os LSP servers necessários (requer Node.js e Python via asdf).

### LSP Servers suportados

- TypeScript/JavaScript: `typescript-language-server`
- Python: `pyright`, `ruff`
- Ruby: `solargraph`
- E mais via Mason

## 🖥️ Tmux

Terminal multiplexer com suporte a persistência de sessões via `tmux-resurrect` e `tmux-continuum`.

### Instalação dos plugins

Após abrir o Tmux pela primeira vez, instale os plugins:
```bash
tmux
# Pressione: Ctrl+b + I (maiúsculo)
```

### Persistência de Sessões

As configurações incluem salvamento automático de sessões a cada 15 minutos com `tmux-continuum`. Isso significa:

- ✅ Suas sessões serão salvas automaticamente
- ✅ Ao reiniciar a máquina, as sessões são restauradas
- ✅ Histórico de panes é mantido

**Como funciona internamente:**
1. `tmux-resurrect` salva estado de sessões, windows e panes
2. `tmux-continuum` automatiza esse salvamento a cada 15 minutos
3. Dados são armazenados em: `~/.local/share/tmux/resurrect/`
4. Ao iniciar tmux novamente, as sessões são restauradas automaticamente

### Keybinds principais

```
Prefix: Ctrl+b (padrão)

# Gerenciamento de sessões
Ctrl+b c      # Nova window
Ctrl+b n      # Próxima window
Ctrl+b p      # Window anterior
Ctrl+b ,      # Renomear window

# Navegação entre painéis (vim-style)
Ctrl+b h      # Paine à esquerda
Ctrl+b j      # Paine abaixo
Ctrl+b k      # Paine acima
Ctrl+b l      # Paine à direita

# Ressurreição de sessões (manual)
Ctrl+b Ctrl+s # Salvar manualmente
Ctrl+b Ctrl+r # Restaurar manualmente

# Plugins customizados
Ctrl+b Ctrl+l # Listar windows com fzf
Ctrl+b Ctrl+n # Abrir notas (nvim popup)
Ctrl+b Ctrl+h # Abrir htop (popup)
Ctrl+b r      # Recarregar configuração
```

### Troubleshooting do Tmux

**Sessões não são salvas:**
```bash
# Verificar se o diretório existe
ls -la ~/.local/share/tmux/resurrect/

# Se não existir, criar:
mkdir -p ~/.local/share/tmux/resurrect/

# Recarregar config
tmux source-file ~/.tmux.conf
```

**Plugins não carregam:**
```bash
# Reinstalar TPM
rm -rf ~/.tmux/plugins/tpm
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Reabrir tmux e instalar plugins (Ctrl+b + I)
tmux
```

## ⚙️ Configurações locais

Para adicionar configurações específicas desta máquina (que não devem ir para o repositório):

```bash
# Crie o arquivo
touch ~/.zshrc.local

# Adicione suas configs, exemplo:
# export PATH="/opt/custom/bin:$PATH"
# alias deploy="./deploy.sh"
```

Este arquivo é carregado automaticamente pelo `.zshrc` mas não está versionado.

## 🐛 Troubleshooting

### Node.js não encontrado no Neovim

```bash
# Recarregar o shell
exec zsh -l

# Verificar se asdf carregou
asdf current

# Reinstalar Node.js
asdf install nodejs lts
asdf reshim nodejs
```

### Mason falha ao instalar LSP servers

```bash
# Verificar se as dependências estão instaladas
node --version
python --version

# Reinstalar via Mason no Neovim
:Mason
# Selecione o server e pressione 'i' para instalar
```

### Permissões no Ubuntu/Linux

Se encontrar erros de permissão:
```bash
# Executar sem sudo
bash setup.sh

# Para mudar o shell
chsh -s $(which zsh)
```

## 📝 Sistemas suportados

- ✅ macOS (Intel e Apple Silicon)
- ✅ Ubuntu/Debian Linux
- ✅ Outras distribuições Linux (com ajustes no script)

## 🔄 Atualizar

```bash
cd ~/dotfiles
git pull origin main
bash setup.sh
```

## 📚 Documentação adicional

- [asdf](https://asdf-vm.com/)
- [Neovim](https://neovim.io/)
- [Lazy.nvim](https://github.com/folke/lazy.nvim)
- [Starship](https://starship.rs/)
- [Tmux](https://github.com/tmux/tmux)

---

**Dica**: Após a instalação, reinicie o terminal e abra o Neovim para finalizar a configuração.
