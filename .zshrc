# Lightweight startup profiler. Set ZSH_STARTUP_REPORT=0 to hide the report.
zmodload zsh/datetime 2>/dev/null
typeset -gF _ZSH_STARTUP_T0=$EPOCHREALTIME
typeset -gF _ZSH_STARTUP_LAST=$_ZSH_STARTUP_T0
typeset -ga _ZSH_STARTUP_NAMES=()
typeset -ga _ZSH_STARTUP_MS=()
typeset -ga _ZSH_STARTUP_FILES=()
typeset -ga _ZSH_STARTUP_FILE_MS=()

if [[ ${ZSH_STARTUP_ZPROF:-0} == 1 ]]; then
  zmodload zsh/zprof
fi

_zsh_startup_mark() {
  local now=$EPOCHREALTIME
  _ZSH_STARTUP_NAMES+=("$1")
  _ZSH_STARTUP_MS+=("$(( (now - _ZSH_STARTUP_LAST) * 1000.0 ))")
  _ZSH_STARTUP_LAST=$now
}

# Track every file sourced while .zshrc is loading. The wrapper is removed at
# the end, so it has no effect on normal interactive shell usage.
source() {
  local file=$1 started=$EPOCHREALTIME _zsh_src_status
  builtin source "$@"
  _zsh_src_status=$?
  _ZSH_STARTUP_FILES+=("${file:A}")
  _ZSH_STARTUP_FILE_MS+=("$(( (EPOCHREALTIME - started) * 1000.0 ))")
  return $_zsh_src_status
}

_zsh_startup_mark "profiler bootstrap"

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Avoid an occasional update check on the critical startup path. Update
# manually with `omz update` when desired.
zstyle ':omz:update' mode disabled

# Avoid invoking `docker completion zsh` in the background for every shell.
# The bundled completion keeps autocomplete while making startup predictable.
zstyle ':omz:plugins:docker' legacy-completion yes

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git z zsh-autosuggestions zsh-syntax-highlighting python docker docker-compose systemd aliases laravel)

source $ZSH/oh-my-zsh.sh
_zsh_startup_mark "Oh My Zsh + plugins + custom/*.zsh"

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# NVM used to account for most of startup. Resolve its default Node alias with
# zsh builtins, but defer loading nvm.sh until the first `nvm` command.
export NVM_DIR="$HOME/.config/nvm"
typeset -U path PATH
typeset _nvm_default _nvm_alias_file _nvm_next
typeset -a _nvm_node_bins
[[ -r "$NVM_DIR/alias/default" ]] && _nvm_default=$(<"$NVM_DIR/alias/default")
for _nvm_alias_depth in {1..5}; do
  _nvm_alias_file="$NVM_DIR/alias/$_nvm_default"
  [[ -r $_nvm_alias_file ]] || break
  _nvm_next=$(<"$_nvm_alias_file")
  [[ -n $_nvm_next && $_nvm_next != $_nvm_default ]] || break
  _nvm_default=$_nvm_next
done
if [[ -d "$NVM_DIR/versions/node/$_nvm_default/bin" ]]; then
  path=("$NVM_DIR/versions/node/$_nvm_default/bin" $path)
else
  _nvm_node_bins=("$NVM_DIR"/versions/node/v<->.<->.<->/bin(NOn[1]))
  (( ${#_nvm_node_bins} )) && path=("$_nvm_node_bins[1]" $path)
fi
unset _nvm_default _nvm_alias_file _nvm_next _nvm_alias_depth _nvm_node_bins

nvm() {
  unfunction nvm
  builtin source "$NVM_DIR/nvm.sh" --no-use
  nvm "$@"
}

[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
_zsh_startup_mark "NVM lazy loader + completion"

export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# Reuse keychain's cached agent environment. Starting/discovering an agent is
# only necessary after reboot or when its socket is gone.
if [[ ! -S ${SSH_AUTH_SOCK:-} && -r "$HOME/.keychain/${HOST%%.*}-sh" ]]; then
  source "$HOME/.keychain/${HOST%%.*}-sh"
fi
if [[ ! -S ${SSH_AUTH_SOCK:-} ]]; then
  eval "$(keychain add --eval --quiet id_ed25519 id_rsa)"
fi
_zsh_startup_mark "SSH keychain cache"


source "$HOME/.local/share/../bin/env"
_zsh_startup_mark "~/.local/bin/env + PATH"

# The emoji definitions are large. Keep the two public commands, but load the
# plugin data only on first use.
_load_omz_emoji() {
  unfunction random_emoji display_emoji
  builtin source "$ZSH/plugins/emoji/emoji.plugin.zsh"
}
random_emoji() { _load_omz_emoji; random_emoji "$@"; }
display_emoji() { _load_omz_emoji; display_emoji "$@"; }
_zsh_startup_mark "emoji lazy loader"

typeset -gF _ZSH_STARTUP_TOTAL_MS=$(( (EPOCHREALTIME - _ZSH_STARTUP_T0) * 1000.0 ))
unfunction source

zsh-startup-report() {
  local mode=${1:-summary} i row
  local -a rows
  printf '\e[36m[zsh startup]\e[0m %.1f ms — %d sourced files\n' \
    "$_ZSH_STARTUP_TOTAL_MS" "${#_ZSH_STARTUP_FILES}"
  for (( i = 1; i <= ${#_ZSH_STARTUP_NAMES}; i++ )); do
    printf '  %7.1f ms  %s\n' "${_ZSH_STARTUP_MS[i]}" "${_ZSH_STARTUP_NAMES[i]}"
  done
  if [[ $mode == all ]]; then
    printf '  -- sourced files, slowest first (inclusive time) --\n'
    for (( i = 1; i <= ${#_ZSH_STARTUP_FILES}; i++ )); do
      rows+=("${_ZSH_STARTUP_FILE_MS[i]}"$'\t'"${_ZSH_STARTUP_FILES[i]}")
    done
    for row in ${(On)rows}; do
      printf '  %7.1f ms  %s\n' "${row%%$'\t'*}" "${row#*$'\t'}"
    done
  else
    printf '  detail: zsh-startup-report all | functions: zsh-startup-profile\n'
  fi
}

zsh-startup-profile() {
  ZSH_STARTUP_REPORT=1 ZSH_STARTUP_ZPROF=1 zsh -i -c exit
}

[[ ${ZSH_STARTUP_REPORT:-1} != 0 && -t 1 ]] && zsh-startup-report

if [[ ${ZSH_STARTUP_ZPROF:-0} == 1 ]]; then
  printf '\n-- zprof function timings --\n'
  zprof
fi

unset _ZSH_STARTUP_LAST
