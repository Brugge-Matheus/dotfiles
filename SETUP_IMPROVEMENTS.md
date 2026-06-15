# Setup.sh — Melhorias de Idempotência

## ✅ O que foi implementado

### 1. **Git Pull Automático**
- No início da execução, o script faz `git pull --ff-only` dos dotfiles
- Verificação segura: só faz pull se não houver mudanças locais
- Detecta quando há atualizações no remote antes de fazer pull

```bash
# Exemplo de fluxo:
git clone dotfiles && bash setup.sh
# → Faz git pull automaticamente
# → Baixa versões mais recentes de configurações
```

### 2. **Atualização de Repositórios Clonados**
Repositórios já existentes agora são atualizados (em vez de apenas pulados):
- ✅ asdf
- ✅ zsh-autosuggestions
- ✅ zsh-syntax-highlighting
- ✅ TPM (Tmux Plugin Manager)

```bash
# Função reutilizável:
git_pull_if_dirty "$repo_path" "nome"
# → Verifica mudanças locais
# → Faz fetch para detectar novidades
# → Faz pull apenas se há novidades
```

### 3. **Symlinks Inteligentes**
Função `safe_link()` agora verifica integridade:
- Detecta se symlink já aponta para o local correto → pula
- Detecta se aponta para lugar errado → atualiza
- Fazer backup de arquivos antigos antes de sobrescrever

```bash
# Exemplo:
# Primeira vez: ~/.zshrc não existe
#   → cria symlink
# Segunda vez: ~/.zshrc aponta para ~/dotfiles/zsh/.zshrc
#   → detecta como correto, pula (log: "já correto")
# Terceira vez: ~/dotfiles/zsh/.zshrc mudou de lugar
#   → atualiza symlink
```

### 4. **Detecção de Primeira Execução vs Re-execução**
Arquivo de estado em `~/.dotfiles-setup-state`:
- Primeira vez: arquivo não existe
- Re-execuções: arquivo marca data/hora da última execução
- Log diferenciado para cada caso

```bash
# Exemplo de saída:
🆕 Primeira execução do setup detectada
# (ou)
🔄 Re-execução detectada (último: 2026-04-10 13:15:42)
```

### 5. **Rastreamento de Histórico**
Novo arquivo: `~/.dotfiles-setup-state`
- Armazena timestamp da última execução bem-sucedida
- Permite identificar quando o setup foi rodado
- Útil para debugging e auditoria

```bash
$ cat ~/.dotfiles-setup-state
2026-04-10 13:25:33
```

## 🔄 Cenários Cobertos

### Cenário 1: Primeira Máquina (Novo Device)
```bash
git clone https://github.com/Brugge-Matheus/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash setup.sh
# → git pull (nada a fazer, acabou de clonar)
# → Instala tudo do zero
# → Cria todos os symlinks
# → Arquivo de estado criado
```

### Cenário 2: Re-executar em Máquina Existente
```bash
cd ~/dotfiles
bash setup.sh
# → git pull (busca atualizações)
# → Pula instalações já existentes
# → Atualiza repositórios clonados (asdf, plugins zsh, etc)
# → Verifica integridade de symlinks (repara se necessário)
# → Atualiza arquivo de estado
```

### Cenário 3: Sincronizar Depois de Mudanças
```bash
# No repositório central, você fez mudanças:
git commit -am "Update tmux config"
git push origin main

# Na sua máquina:
cd ~/dotfiles
bash setup.sh
# → git pull (baixa as mudanças)
# → Atualiza .tmux.conf automaticamente via symlink
# → Atualiza plugins do tmux
```

### Cenário 4: Segunda Máquina (Clone do Repositório)
```bash
git clone https://github.com/Brugge-Matheus/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash setup.sh
# → git pull (mais recente do remote)
# → Instala todas as configurações
# → Primeiro setup nesta máquina
```

## 📊 Comparação: Antes vs Depois

| Feature | Antes | Depois |
|---------|-------|--------|
| Git pull automático | ❌ | ✅ |
| Atualização de repos | ❌ | ✅ |
| Verificação de symlinks | ⚠️ Básica | ✅ Inteligente |
| Detecção de primeira execução | ❌ | ✅ |
| Rastreamento de histórico | ❌ | ✅ |
| Idempotência | ❌ Parcial | ✅ Completa |

## 🚀 Como Usar

### Primeira Vez em um Device
```bash
git clone https://github.com/Brugge-Matheus/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash setup.sh
exec zsh -l
```

### Atualizar Depois de Mudanças
Quando você fizer mudanças no repositório e quiser sincronizar:
```bash
bash ~/dotfiles/setup.sh
# Automaticamente:
# - Faz git pull
# - Atualiza symlinks se necessário
# - Atualiza plugins
```

### Rodar Periodicmente
Você pode até adicionar um cron job se quiser:
```bash
# ~/.crontab
0 9 * * 0 bash ~/dotfiles/setup.sh >> ~/dotfiles-setup.log 2>&1
# (toda segunda às 9h, faz setup)
```

## 📝 Logs e Debugging

Para ver o histórico de execuções:
```bash
cat ~/.dotfiles-setup-state
# Mostra data/hora da última execução

# Para ver log completo de uma execução:
bash ~/dotfiles/setup.sh 2>&1 | tee ~/dotfiles-setup-$(date +%s).log
```

## ✨ Benefícios Finais

✅ **Setup completamente idempotente** - rodar múltiplas vezes é seguro
✅ **Sincronização automática** - git pull embutido
✅ **Atualizações de dependências** - repositórios clonados são atualizados
✅ **Symlinks robustos** - verificação de integridade
✅ **Rastreamento de estado** - saber quando/se o setup foi executado
✅ **Sem perda de dados** - .zshrc.local, sessões tmux, etc ficam intactas
✅ **Cross-platform** - funciona em macOS e Linux
