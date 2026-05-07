# Proteção: só executa se estiver rodando zsh
if [ -z "$ZSH_VERSION" ]; then
  echo "⚠️  Este arquivo é apenas para Zsh. Shell atual: $SHELL"
  echo "   Execute: exec zsh"
  return 2>/dev/null || exit 0
fi

# --- HISTÓRICO ---
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt sharehistory
setopt hist_ignore_dups
setopt hist_ignore_space

# --- CORES E COMPLETAR ---
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors ''
export LS_COLORS='rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=30;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.zip=01;31:*.gz=01;31:*.bz2=01;31:*.7z=01;31:*.jpg=01;35:*.jpeg=01;35:*.png=01;35:*.gif=01;35:*.mp4=01;35:*.mkv=01;35:*.mp3=00;36:*.wav=00;36:'

# --- ALIASES ---
if command -v gls &>/dev/null; then
  alias ls='gls --color=auto'  # macOS com coreutils via homebrew
else
  alias ls='ls --color=auto'   # Linux
fi
alias grep='grep --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias c='clear'

# --- DESENVOLVIMENTO ---

# Ruby on Rails
alias rs='rails server'
alias rc='rails console'
alias bi='bundle install'
alias migrate='bundle exec rake db:migrate'

# PHP / Laravel
alias sail='./vendor/bin/sail'
alias pint='./vendor/bin/pint'
alias pest='./vendor/bin/pest'

# --- PLUGINS ---
[ -f "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && \
  source "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"

[ -f "$HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && \
  source "$HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# --- PATH ---
export PATH="$HOME/.local/bin:$PATH"

# Homebrew (macOS ARM)
if [ -f /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Homebrew (Linux)
if [ -f /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# GNU coreutils no macOS
if [ -d "/opt/homebrew/opt/coreutils/libexec/gnubin" ]; then
  export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
fi

# asdf
[ -f "$HOME/.asdf/asdf.sh" ] && source "$HOME/.asdf/asdf.sh"
[ -f /opt/homebrew/opt/asdf/libexec/asdf.sh ] && source /opt/homebrew/opt/asdf/libexec/asdf.sh

# --- LOCALE ---
unset LOCPATH
export LANG=en_US.UTF-8

# --- VIM MOTIONS ---
bindkey -v
bindkey -M viins jj vi-cmd-mode

# Carregar módulo menuselect para navegação no menu de completar
zmodload zsh/complist
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history

bindkey -v '^?' backward-delete-char

function zle-line-init zle-keymap-select {
  if [[ $KEYMAP == vicmd ]]; then
    echo -ne '\e[2 q'
  else
    echo -ne '\e[6 q'
  fi
  zle reset-prompt
}

zle -N zle-line-init
zle -N zle-keymap-select

# --- PROMPT (por último) ---
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
fi

# --- LOCAL OVERRIDES (não commitar) ---
# Adicione configs específicas desta máquina em ~/.zshrc.local
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/brugge-matheus/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/brugge-matheus/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/Users/brugge-matheus/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/brugge-matheus/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

