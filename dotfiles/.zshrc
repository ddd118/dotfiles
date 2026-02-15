# shellcheck disable=all
# ------------------------------------------------------------
# Powerlevel10k instant prompt (できるだけ上のほうに置く)
# ここより下で「起動時に画面出力」すると崩れることがあるので、
# プラグインは“存在する時だけ”読み込むようにするのが安全。
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ------------------------------------------------------------
# Linux Mint: zsh-newuser-install のベース（衝突時はこれを優先）
HISTFILE="$HOME/.histfile"
HISTSIZE=1000
SAVEHIST=1000
setopt autocd beep extendedglob nomatch notify
bindkey -v
zstyle :compinstall filename "$HOME/.zshrc"

# ------------------------------------------------------------
# 判定ヘルパー
is_wsl() {
  [[ -n "${WSL_DISTRO_NAME-}" ]] || grep -qi microsoft /proc/version 2>/dev/null
}
is_container() {
  [[ -f "/.dockerenv" ]] || [[ -n "${REMOTE_CONTAINERS-}${DEVCONTAINER-}" ]]
}

# ------------------------------------------------------------
# 環境変数（必要最低限）
export LANG="${LANG:-ja_JP.UTF-8}"
export LANGUAGE="${LANGUAGE:-ja_JP:ja}"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--R}"
export EDITOR="${EDITOR:-vim}"
# Codex 用
export VISUAL="${EDITOR}"
# CLAUDEのMCPツールを動的に読み込むようにする
export ENABLE_TOOL_SEARCH=true

if is_wsl; then
  export BROWSER="${BROWSER:-wslview}"
else
  export BROWSER="${BROWSER:-xdg-open}"
fi

# 補完候補が多すぎる時だけ確認（値は好みで）
LISTMAX=1000
# 3秒以上かかったコマンドは実行時間を表示
REPORTTIME=3

# 重複除去（path 等を array として扱う zsh の機能）
typeset -U path cdpath fpath manpath

# cd の検索パス（`cd foo` を $HOME/foo と解釈できる）
cdpath=("$HOME" $cdpath)

# WORDCHARS 調整（Ctrl+W 等の「単語」境界）
# `|` と `:` を単語扱いしたくない場合に除外
WORDCHARS=${WORDCHARS//[|:]/}

# ------------------------------------------------------------
# PATH 追加（重複しても typeset -U path で整理される）
path=("$HOME/.local/bin" "$HOME/bin" $path)

# Volta（使ってるなら PATH を通すだけでOK）
if [[ -d "$HOME/.volta/bin" ]]; then
  export VOLTA_HOME="${VOLTA_HOME:-$HOME/.volta}"
  export VOLTA_FEATURE_PNPM=1
  path=("$VOLTA_HOME/bin" $path)
fi

# pnpm（installer 方式のとき用。Volta/Node経由だけなら不要なことも多い）
export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
if [[ -d "$PNPM_HOME" ]]; then
  path=("$PNPM_HOME" $path)
fi

# 独自補完を置くディレクトリ（compinit より前が安全）
if [[ -d "$HOME/.zsh/completions" ]]; then
  fpath=("$HOME/.zsh/completions" $fpath)
fi

# compinit 前に必要な補完（git-gtr）
git gtr --help > /dev/null 2>&1 && eval "$(git gtr completion zsh)"

# dircolors（ファイルがあるときだけ）
if command -v dircolors >/dev/null 2>&1 && [[ -f "$HOME/.dir_colors" ]]; then
  eval "$(dircolors "$HOME/.dir_colors")"
fi

# ------------------------------------------------------------
# oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"

# p10k instant prompt と相性問題（compfixの対話など）を避けたい場合
ZSH_DISABLE_COMPFIX="true"

# コンテナは起動が頻繁なので auto update を切りたい場合
if is_container; then
  DISABLE_AUTO_UPDATE="true"
fi

# テーマ：p10k が無い環境では fallback
if [[ -r "${ZSH_CUSTOM:-$ZSH/custom}/themes/powerlevel10k/powerlevel10k.zsh-theme" ]]; then
  ZSH_THEME="powerlevel10k/powerlevel10k"
else
  ZSH_THEME="robbyrussell"
fi

# プラグイン：存在するものだけ有効化（起動時の警告出力を防ぐ）
plugins=(
	git
  docker
  npm
)

# スペルミス補正
ENABLE_CORRECTION="true"

# oh-my-zsh 自動更新設定（7日毎に設定）
zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 7

# 外部コマンドがある時だけ（fzf/zoxide/volta は“バイナリ必須”）
(( $+commands[fzf] ))    && plugins+=(fzf)
(( $+commands[zoxide] )) && plugins+=(zoxide)
(( $+commands[volta] ))  && plugins+=(volta)

# ユーザープラグイン（clone済みのときだけ）
if [[ -d "${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-autosuggestions" ]]; then
  plugins+=(zsh-autosuggestions)
fi
if [[ -d "${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-bat" ]]; then
  plugins+=(zsh-bat)
fi
# syntax-highlighting は最後に読みたいので最後尾に
if [[ -d "${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-syntax-highlighting" ]]; then
  plugins+=(zsh-syntax-highlighting)
fi

# 読み込み（これが compinit も内部でやる）
if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  # oh-my-zsh 無い環境の保険
  autoload -Uz compinit && compinit
fi

# ------------------------------------------------------------
# setopt（WSL時代のやつから “安全で便利” 寄りを統合）
setopt correct
setopt auto_list
setopt auto_menu
setopt complete_in_word
setopt interactive_comments
setopt magic_equal_subst
setopt globdots
setopt prompt_subst
setopt rm_star_wait

setopt share_history
setopt hist_reduce_blanks
setopt hist_ignore_all_dups
setopt hist_expire_dups_first
setopt hist_no_store
setopt hist_no_functions
setopt extended_history

setopt auto_pushd
setopt pushd_ignore_dups
setopt numeric_glob_sort
setopt multios

# 注意：これは癖が強いのでデフォルトOFF推奨
# setopt sh_word_split

# 引数に対しては補完を無効化する
unsetopt correctall

# ------------------------------------------------------------
# zstyle（補完の見た目・挙動）
zstyle ':completion:*' menu select
zstyle ':completion:*' verbose yes
zstyle ':completion:*' use-cache true
zstyle ':completion:*' list-separator '-->'
zstyle ':completion:*' group-name ''

# . と .. を補完候補から除外
zstyle ':completion:*' special-dirs false

# 候補の色（LS_COLORS がある時だけ）
if [[ -n "${LS_COLORS-}" ]]; then
  zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
fi

# completer（候補生成の戦略：広げる/普通/部分一致/近似など）
zstyle ':completion:*' completer _expand _complete _match _prefix _approximate _history

# 表示メッセージ（%F{color} は zsh の色）
zstyle ':completion:*:messages' format '%F{yellow}%d%f'
zstyle ':completion:*:warnings' format '%F{red}No matches for:%f %F{yellow}%d%f'
zstyle ':completion:*:descriptions' format '%F{yellow}completing %B%d%b%f'
zstyle ':completion:*:corrections' format '%F{yellow}%B%d %F{red}(errors: %e)%f%b'
zstyle ':completion:*:options' description 'yes'

# いらないファイルを補完候補から除外
zstyle ':completion:*:*files' ignored-patterns '*?.o' '*?~' '*\#'

# cd 補完
zstyle ':completion:*:cd:*' tag-order local-directories path-directories
zstyle ':completion:*:cd:*' ignore-parents parent pwd

# man 補完
zstyle ':completion:*:manuals' separate-sections true

# kill の候補に色付け
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([%0-9]#)*=0=01;31'
zstyle ':completion:*:processes' command 'ps x -o pid,s,args'

# sudo 付きでも補完
zstyle ':completion:*:sudo:*' command-path /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin

# predict を使うなら（今はOFFでも設定だけ残してOK）
zstyle ':predict' verbose true

# ------------------------------------------------------------
# bindkey（vi mode + 実用）
KEYTIMEOUT=1

autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line

# Ctrl+Arrow（端末によっては効かないが害はない）
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '\e[1;5C'  forward-word
bindkey '\e[1;5D'  backward-word

# ------------------------------------------------------------
# Alias（WSL依存はガード）
alias sudo="sudo "
alias mkdir="mkdir -p"
alias mv="mv -i"
alias cp="cp -i"
alias ls="ls -F --color=auto"
alias la="ls -A"
alias ll='ls -Alhrt --time-style="+%Y-%m-%d %H:%M:%S"'
alias sl="ls"
alias py="python3"
alias pipi="pip install"
alias rez="exec zsh"
alias edc="${EDITOR:-vim} ~/.zshrc"
alias memo="${EDITOR:-vim} ~/memo.md"

if is_wsl; then
  alias C="clip.exe"
  command -v xclip >/dev/null 2>&1 && alias xclip="xclip -selection clipboard"
fi

alias claude-resume="npx @sasazame/ccresume@latest"
alias codex-resume="npx cdxresume@latest"
alias gwr="git gtr"

# ------------------------------------------------------------
# 関数：cdしたらls（好み）
autoload -Uz add-zsh-hook
cdls() {
  ls
}
add-zsh-hook chpwd cdls

# Git Worktree Repair（そのまま移植：壊れにくいように少し堅く）
repair_repo() {
  local repo="${1:-$PWD}"

  local repo_git_dir
  repo_git_dir="$(git -C "$repo" rev-parse --git-dir 2>/dev/null)" || return 0
  git rev-parse --resolve-git-dir "$repo_git_dir" >/dev/null 2>&1 || return 0

  local real_top
  real_top="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)" || return 0
  [[ -n "$real_top" ]] || return 0

  local worktrees wt tree_path
  worktrees=("${(@f)$(git -C "$repo" worktree list --porcelain | awk '/^worktree /{print $2}')}")

  for wt in $worktrees; do
    [[ "$wt" == "$real_top"* ]] && continue
    tree_path="${wt/#*.worktrees/.worktrees}"
    if [[ -d "${real_top}/${tree_path}" ]]; then
      git -C "$real_top" worktree repair "${real_top}/${tree_path}" >/dev/null 2>&1 || true
    fi
  done
}

# 起動時に修復（不要ならコメントアウト）
if ! is_container; then
  repair_repo
fi

# WSL限定関数
if is_wsl command -v powershell.exe >/dev/null 2>&1; then
  # クリップボードの中身をログに出力する
  cb2log () {
    local out="${1:-logs/$(date +%Y%m%d-%H%M%S).log}"
    local dir="$(dirname "$out")"

    if ! mkdir -p "$dir"; then
      echo "error: failed to create directory: $dir" >&2
      return 1
    fi

    if ! powershell.exe -NoProfile \
      -Command "[Console]::OutputEncoding=[Text.Encoding]::UTF8; Get-Clipboard -Raw" \
      | tr -d '\r' > "$out"; then
      echo "error: failed to read clipboard or write: $out" >&2
      return 1
    fi
  }
fi

# コンテナ内限定関数
if is_container; then
  # pnpm の store_dir 環境変数を無効化した上で実行するラッパー
  npm() { env -u npm_config_store_dir command npm "$@"; }
  npx() { env -u npm_config_store_dir command npx "$@"; }
fi

# ------------------------------------------------------------
# 外部env（あれば）
[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"

# autosuggestions の確定キー（プラグインがある時だけ）
if (( $+functions[autosuggest-accept] )); then
  bindkey -M viins '^ ' autosuggest-accept
fi

# p10k 設定（末尾）
[[ ! -f "$HOME/.p10k.zsh" ]] || source "$HOME/.p10k.zsh"
