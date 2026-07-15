alias reload='source ~/.zshrc'

if command -v eza &>/dev/null; then
  alias ls="eza --group-directories-first --color=auto"
  alias ll="eza -alh --git --octal-permissions --group-directories-first --color=auto"
  alias la="eza -A --group-directories-first --color=auto"
  alias l="eza -alh --git --group-directories-first --sort=changed --reverse --color=auto"
else
  if [[ "$OSTYPE" == "darwin"* ]]; then
    export LS_CMD="gls --color=auto"
  else
    export LS_CMD="ls --color=auto"
  fi
  alias ls="$LS_CMD"
  alias ll="$LS_CMD -alh"
  alias la="$LS_CMD -A"
  alias l="$LS_CMD -lahrtc"
fi

alias gs="git status"
alias gst="git status"
alias gadd="git add -A && git status -sb"
alias update_submodules="git pull --recurse-submodules && git submodule update"
alias grh_git_reset_hard="git reset --hard"
alias grhc_git_reset_hard_clean="git reset --hard && git clean -fd"
alias gprune="git fetch --prune"

# Syntax highlighting for less (-R for RAW ^ colors)
alias less='less -R'

alias path='echo $PATH'

# Verbosely show progress for move and copy
alias cp='cp -v'
alias mv='mv -v'

# Drop any stale aliases so re-sourcing this file can redefine these as
# functions (zsh errors on `name()` if `name` is currently an alias).
unalias pbcopy uuid 2>/dev/null

# Inside tmux, route pbcopy to the local clipboard via an OSC 52 escape
# sequence (tmux forwards it to the outer terminal). Outside tmux, fall
# back to native pbcopy on macOS, or bare OSC 52 elsewhere.
pbcopy() {
  if [[ -n "$TMUX" ]]; then
    printf '\033Ptmux;\033\033]52;c;%s\007\033\\' "$(base64 | tr -d '\n')" > /dev/tty
  elif [[ -x /usr/bin/pbcopy ]]; then
    /usr/bin/pbcopy
  else
    printf '\033]52;c;%s\007' "$(base64 | tr -d '\n')" > /dev/tty
  fi
}

# Copy the current tmux pane's scrollback to the clipboard via pbcopy above.
# -S - grabs from the top of history, -J unwraps long lines. The awk pass
# drops everything from the pbwindow invocation line onward (plus any trailing
# blank lines) so the command that triggered the copy isn't included; it cuts
# at the last "pbwindow" match, which is always the invocation at the bottom,
# leaving earlier legitimate mentions intact. Bounded by tmux's history-limit.
# Only works inside tmux -- terminal scrollback isn't reachable from the shell
# outside a multiplexer.
pbwindow() {
  if [[ -z "$TMUX" ]]; then
    printf 'pbwindow: only works inside tmux (terminal scrollback is not reachable otherwise)\n' >&2
    return 1
  fi
  tmux capture-pane -pJS - | awk '
    { lines[NR] = $0 }
    /pbwindow/ { cut = NR }
    END {
      end = cut ? cut - 1 : NR
      while (end > 0 && lines[end] == "") end--
      for (i = 1; i <= end; i++) print lines[i]
    }
  ' | pbcopy
}

# Generate a UUID, copy it to the clipboard, and print it. Uses a captured
# value instead of pbpaste so it works on remote hosts (where the OSC 52
# pbcopy above has no paste counterpart).
uuid() {
  local id
  id=$(uuidgen | tr -d '\n' | tr '[:upper:]' '[:lower:]')
  printf '%s' "$id" | pbcopy
  printf '%s\n' "$id"
}
alias flushdns="sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"

alias k="kubectl"

alias ws="clear && cd ~/workspace/"
rp() {
  local resolved
  resolved=$(realpath "$@") || return
  printf '%s' "$resolved" | pbcopy
  printf '%s\n' "$resolved"
}
alias dotfiles="clear && cd ~/workspace/dotfiles/"
alias bootstrap="(cd ~/workspace/dotfiles && ./bootstrap.sh)"

alias ccusage-today='ccusage daily -b -s $(date +%Y%m%d) -u $(date +%Y%m%d)'

alias build="docker compose build"
alias up="docker compose up"
alias upd="docker compose up -d"
alias down="docker compose down"
alias logs="docker compose logs -f"
