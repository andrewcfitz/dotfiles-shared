#!/bin/bash

set -e

# --- Logging helpers ---
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
RESET='\033[0m'

log_section() { printf "\n${BOLD}${BLUE}==> %s${RESET}\n" "$1"; }
log_info()    { printf "${GREEN}  [ok]${RESET} %s\n" "$1"; }
log_action()  { printf "${YELLOW}  [..]${RESET} %s\n" "$1"; }
log_skip()    { printf "${DIM}  [--] %s${RESET}\n" "$1"; }
log_warn()    { printf "${YELLOW}  [!!] %s${RESET}\n" "$1" >&2; }
log_error()   { printf "${RED}  [!!] %s${RESET}\n" "$1" >&2; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Bootstrap a macOS development environment by symlinking dotfiles,
installing packages, and configuring system settings.

With no flags, all sections run. Pass one or more flags to run only
those sections.

Options:
  -h, --help        Show this help message and exit
  --pull            Pull main repo and shared submodule; commit shared bump
                    (opt-in only; not run when no flags are passed)
  --init            Run init.sh (git submodule setup)
  --homebrew        Install Homebrew and run brew bundle
  --symlinks        Clean up broken symlinks and link dotfiles
  --antidote        Install the Antidote zsh plugin manager
  --macos           Apply macOS defaults (Dock, .osx); also runs
                    bootstrap.local.macos.sh if present
  --ssh             Configure sshd PATH for non-interactive sessions
  --et              Start Eternal Terminal server at login
  --claude          Install Claude Code
  --iterm           Install iTerm2 AI plugin
  --tmux            Install tmux plugin manager (TPM) and plugins
  --local           Run repo-local bootstrap.local.sh if present

Examples:
  $(basename "$0")                  # run everything
  $(basename "$0") --homebrew       # only install/update brew packages
  $(basename "$0") --symlinks --macos  # only symlinks and macOS defaults
EOF
    exit 0
}

# Parse flags
RUN_PULL=0
RUN_INIT=0
RUN_HOMEBREW=0
RUN_SYMLINKS=0
RUN_ANTIDOTE=0
RUN_MACOS=0
RUN_SSH=0
RUN_ET=0
RUN_CLAUDE=0
RUN_ITERM=0
RUN_TMUX=0
RUN_LOCAL=0
RUN_ALL=1

for arg in "$@"; do
    case "$arg" in
        -h|--help)     usage ;;
        --pull)        RUN_PULL=1;      RUN_ALL=0 ;;
        --init)        RUN_INIT=1;     RUN_ALL=0 ;;
        --homebrew)    RUN_HOMEBREW=1;  RUN_ALL=0 ;;
        --symlinks)    RUN_SYMLINKS=1;  RUN_ALL=0 ;;
        --antidote)    RUN_ANTIDOTE=1;  RUN_ALL=0 ;;
        --macos)       RUN_MACOS=1;     RUN_ALL=0 ;;
        --ssh)         RUN_SSH=1;       RUN_ALL=0 ;;
        --et)          RUN_ET=1;        RUN_ALL=0 ;;
        --claude)      RUN_CLAUDE=1;    RUN_ALL=0 ;;
        --iterm)       RUN_ITERM=1;     RUN_ALL=0 ;;
        --tmux)        RUN_TMUX=1;      RUN_ALL=0 ;;
        --local)       RUN_LOCAL=1;     RUN_ALL=0 ;;
        *) echo "Unknown option: $arg" >&2; echo "Run '$(basename "$0") --help' for usage." >&2; exit 1 ;;
    esac
done

should_run() {
    [ "$RUN_ALL" -eq 1 ] || [ "$(eval echo \$"RUN_$1")" -eq 1 ]
}

DOTFILES_DIR=$(cd "$(dirname "$0")" && pwd -P)

# --- Pull repos ---
# Opt-in only: never runs as part of bare `bootstrap.sh`. Pulls the outer
# (main) dotfiles repo and the `shared` submodule on its tracked branch. If
# shared moved, commits the pointer bump in the outer repo with a message
# summarizing the included shared commits.
if [ "$RUN_PULL" -eq 1 ]; then
    log_section "Pull"

    # Resolve the outer repo. When run via the bootstrap.sh symlink at the
    # repo root, DOTFILES_DIR resolves to shared/. Walk up if so.
    OUTER_DIR="$DOTFILES_DIR"
    if [ "$(basename "$OUTER_DIR")" = "shared" ]; then
        OUTER_DIR="$(dirname "$OUTER_DIR")"
    fi
    SHARED_DIR="$OUTER_DIR/shared"

    log_action "Pulling $(basename "$OUTER_DIR")..."
    git -C "$OUTER_DIR" pull --rebase --autostash

    old_sha=$(git -C "$SHARED_DIR" rev-parse HEAD)
    log_action "Pulling shared..."
    git -C "$SHARED_DIR" pull --rebase --autostash

    # Pull the avoid-ai-writing skill submodule (tracks main) to its latest
    # upstream commit and, if it moved, commit the pointer bump inside shared.
    # Done before new_sha is read below so it rolls up into the shared bump.
    if git -C "$SHARED_DIR" config --file .gitmodules --get submodule.skills/avoid-ai-writing.url >/dev/null 2>&1; then
        skill_old=$(git -C "$SHARED_DIR" rev-parse HEAD:skills/avoid-ai-writing 2>/dev/null || echo none)
        log_action "Pulling avoid-ai-writing skill..."
        git -C "$SHARED_DIR" submodule update --init --remote --merge skills/avoid-ai-writing
        skill_new=$(git -C "$SHARED_DIR/skills/avoid-ai-writing" rev-parse HEAD)
        if [ "$skill_old" != "$skill_new" ]; then
            git -C "$SHARED_DIR" add skills/avoid-ai-writing
            git -C "$SHARED_DIR" commit -m "bump avoid-ai-writing skill"
            log_info "avoid-ai-writing skill bumped to $(git -C "$SHARED_DIR/skills/avoid-ai-writing" rev-parse --short HEAD)"
        else
            log_skip "avoid-ai-writing skill already up to date"
        fi
    fi

    new_sha=$(git -C "$SHARED_DIR" rev-parse HEAD)

    if [ "$old_sha" != "$new_sha" ]; then
        log_action "Committing shared bump in $(basename "$OUTER_DIR")..."
        summary=$(git -C "$SHARED_DIR" log --format='- %s' "$old_sha..$new_sha")
        git -C "$OUTER_DIR" add shared
        git -C "$OUTER_DIR" commit -m "bump shared

$summary"
        log_info "Shared bumped to $(git -C "$SHARED_DIR" rev-parse --short HEAD)"
    else
        log_skip "Shared already up to date"
    fi
fi

# --- Init ---
if should_run INIT; then
    log_section "Init"
    log_action "Running init.sh..."
    ./init.sh
    log_info "Init complete"
fi

# --- Homebrew install ---
if should_run HOMEBREW; then
    log_section "Homebrew"
    if ! [ -x "$(command -v /opt/homebrew/bin/brew)" ] > /dev/null; then
        log_action "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        log_info "Homebrew installed"
    else
        log_skip "Homebrew already installed"
    fi
fi

export PATH="/opt/homebrew/bin:$PATH"

# --- macOS defaults ---
if should_run MACOS; then
    log_section "macOS Defaults"
    log_action "Setting Dock to autohide..."
    defaults write com.apple.dock autohide -bool true && killall Dock || true
    log_info "Dock configured"
fi

# Remove broken symlinks pointing into dotfiles (shared or local).
# Only scans directories that mirror the dotfiles tree, non-recursively at each
# level — avoids walking huge trees like ~/Library on macOS.
cleanup_broken_symlinks() {
    local files_dir="$1"
    while read -r dir; do
        rel="${dir#"$files_dir"}"
        rel="${rel#/}"
        home_dir="$HOME${rel:+/$rel}"
        [ -d "$home_dir" ] || continue
        while read -r link; do
            target=$(readlink "$link")
            if [[ "$target" == "$files_dir/"* ]] && [ ! -e "$link" ]; then
                read -rp "Remove broken symlink: $link? [y/N] " confirm </dev/tty
                [[ "$confirm" =~ ^[Yy]$ ]] && rm "$link"
            fi
        done < <(find "$home_dir" -maxdepth 1 -type l)
    done < <(find "$files_dir" -type d)
}

# Symlink all files from a given files directory into $HOME
symlink_files() {
    local files_dir="$1"
    find "$files_dir" -type f -not -name ".keepme" | while read -r src; do
        rel="${src#$files_dir/}"
        dest="$HOME/$rel"
        mkdir -p "$(dirname "$dest")"
        ln -sf "$src" "$dest"
    done
}

# Uninstall packages listed in a removal Brewfile. `brew bundle` only installs;
# this handles the inverse. Files use Brewfile syntax (`brew "x"` / `cask "x"`);
# anything not currently installed is skipped quietly.
brew_remove_bundle() {
    local file="$1" line type name
    [ -f "$file" ] || return 0
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"                          # strip trailing comments
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue # skip blank lines
        type=$(printf '%s' "$line" | awk '{print $1}')
        name=$(printf '%s' "$line" | sed -nE 's/.*"([^"]+)".*/\1/p')
        [ -z "$name" ] && continue
        case "$type" in
            cask)
                if brew list --cask "$name" &>/dev/null; then
                    log_action "Removing cask $name..."
                    brew uninstall --cask "$name"
                else
                    log_skip "Cask $name not installed"
                fi
                ;;
            brew)
                if brew list --formula "$name" &>/dev/null; then
                    log_action "Removing $name..."
                    brew uninstall "$name"
                else
                    log_skip "$name not installed"
                fi
                ;;
            *)
                log_warn "Removal: skipping unsupported line ($line)"
                ;;
        esac
    done < "$file"
}

# --- Antidote ---
# Install before symlinks so the plugin manager is present when the shell
# dotfiles (which source ~/.antidote) are linked into place.
if should_run ANTIDOTE; then
    log_section "Antidote"
    if [ ! -d "${ZDOTDIR:-$HOME}/.antidote" ]; then
        log_action "Installing Antidote zsh plugin manager..."
        git clone --depth=1 https://github.com/mattmc3/antidote.git "${ZDOTDIR:-$HOME}/.antidote"
        log_info "Antidote installed"
    else
        log_skip "Antidote already installed"
    fi
fi

# --- Symlinks ---
if should_run SYMLINKS; then
    log_section "Symlinks"
    log_action "Cleaning up broken symlinks..."
    if [ -d "$DOTFILES_DIR/shared/files" ]; then
        cleanup_broken_symlinks "$DOTFILES_DIR/shared/files"
    fi
    cleanup_broken_symlinks "$DOTFILES_DIR/files"

    log_action "Linking dotfiles into \$HOME..."
    if [ -d "$DOTFILES_DIR/shared/files" ]; then
        symlink_files "$DOTFILES_DIR/shared/files"
    fi
    symlink_files "$DOTFILES_DIR/files"

    # VS Code on macOS doesn't honor XDG; redirect its settings.json to ~/.config
    log_action "Linking VS Code settings.json to ~/.config..."
    VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
    mkdir -p "$VSCODE_USER_DIR"
    ln -sfn "$HOME/.config/Code/User/settings.json" "$VSCODE_USER_DIR/settings.json"

    log_info "Symlinks up to date"
fi

# --- Homebrew packages ---
if should_run HOMEBREW; then
    # Run Homebrew non-interactively so upgrades don't stop to ask "[y/n]".
    export NONINTERACTIVE=1
    # Skip "ask mode" confirmation prompts (e.g. "Do you want to proceed with
    # the upgrade?"); NONINTERACTIVE alone doesn't suppress these.
    export HOMEBREW_NO_ASK=1
    log_action "Updating Homebrew..."
    brew update
    log_action "Upgrading all formulae and casks (--greedy)..."
    brew upgrade --greedy
    log_action "Running brew bundle (Brewfile)..."
    brew bundle --file=~/.Brewfile
    log_action "Running brew bundle (Brewfile.shared)..."
    brew bundle --file=~/.Brewfile.shared
    log_action "Processing removal Brewfiles..."
    brew_remove_bundle ~/.Brewfile.remove
    brew_remove_bundle ~/.Brewfile.shared.remove
    log_action "Cleaning up old versions..."
    brew cleanup
    log_info "Homebrew packages up to date"
fi

# --- macOS defaults (.osx) ---
if should_run MACOS; then
    log_action "Running .osx defaults script..."
    ~/.osx
    log_info "macOS defaults applied"

    MACOS_LOCAL_HOOK="$DOTFILES_DIR/bootstrap.local.macos.sh"
    if [ -f "$MACOS_LOCAL_HOOK" ]; then
        log_action "Running $(basename "$MACOS_LOCAL_HOOK")..."
        # shellcheck disable=SC1090
        source "$MACOS_LOCAL_HOOK"
        log_info "macOS local hook complete"
    fi
fi

# --- SSH config ---
if should_run SSH; then
    log_section "SSH Config"
    if ! sudo grep -q 'SetEnv PATH=' /etc/ssh/sshd_config; then
        log_action "Adding Homebrew PATH to sshd_config..."
        echo 'SetEnv PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin' | sudo tee -a /etc/ssh/sshd_config
        sudo launchctl kickstart -k system/com.openssh.sshd
        log_info "sshd_config updated and sshd restarted"
    else
        log_skip "sshd_config already configured"
    fi
fi

# --- Eternal Terminal ---
if should_run ET; then
    log_section "Eternal Terminal"
    if command -v et &> /dev/null && ! et --version &> /dev/null; then
        log_action "et is broken (likely protobuf ABI drift) — rebuilding from source..."
        brew reinstall --build-from-source et
        log_info "et rebuilt"
    fi
    log_action "Starting et service..."
    sudo brew services start et
    log_info "Eternal Terminal service started"
fi

# --- Claude Code ---
if should_run CLAUDE; then
    log_section "Claude Code"
    if ! command -v claude &> /dev/null; then
        log_action "Installing Claude Code..."
        curl -fsSL https://claude.ai/install.sh | bash
        log_info "Claude Code installed"
    else
        log_skip "Claude Code already installed"
    fi

    # avoid-ai-writing skill, vendored as a submodule of shared (tracks main;
    # pulled via --pull). Ensure it's checked out, then point ~/.claude/skills
    # at its canonical skill dir. Whole-dir symlink: the source lives outside
    # files/, so the normal per-file symlink pass doesn't cover it.
    # DOTFILES_DIR may be the outer repo (bootstrap.sh is a symlink at its root),
    # so resolve the shared dir that actually holds the submodule.
    SHARED_BASE="$DOTFILES_DIR"
    if [ "$(basename "$SHARED_BASE")" != "shared" ] && [ -d "$SHARED_BASE/shared" ]; then
        SHARED_BASE="$SHARED_BASE/shared"
    fi
    SKILL_SRC="$SHARED_BASE/skills/avoid-ai-writing"
    if [ ! -e "$SKILL_SRC/SKILL.md" ]; then
        log_action "Initializing avoid-ai-writing submodule..."
        git -C "$SHARED_BASE" submodule update --init skills/avoid-ai-writing
    fi
    SKILL_LINK="$SKILL_SRC/plugins/avoid-ai-writing/skills/avoid-ai-writing"
    if [ -d "$SKILL_LINK" ]; then
        mkdir -p "$HOME/.claude/skills"
        ln -sfn "$SKILL_LINK" "$HOME/.claude/skills/avoid-ai-writing"
        log_info "avoid-ai-writing skill linked"
    else
        log_warn "avoid-ai-writing skill dir missing; skipping symlink"
    fi
fi

# --- iTerm2 AI plugin ---
if should_run ITERM; then
    log_section "iTerm2 AI Plugin"
    ITERM_AI_DIR="$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch/iTermAI"
    if [ ! -d "$ITERM_AI_DIR" ]; then
        log_action "Installing iTerm2 AI plugin..."
        curl -L -o /tmp/iTermAI.zip "https://github.com/gnachman/iterm2-website/raw/refs/heads/master/downloads/ai-plugin/iTermAI-1.1.zip"
        mkdir -p "$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch"
        unzip -qo /tmp/iTermAI.zip -d "$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch"
        rm /tmp/iTermAI.zip
        log_info "iTerm2 AI plugin installed"
    else
        log_skip "iTerm2 AI plugin already installed"
    fi
fi

# --- tmux plugins (TPM) ---
if should_run TMUX; then
    log_section "tmux plugins"
    TPM_DIR="$HOME/.tmux/plugins/tpm"
    if [ ! -d "$TPM_DIR" ]; then
        log_action "Cloning TPM..."
        git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
        log_info "TPM installed"
    else
        log_skip "TPM already installed"
    fi
    log_action "Installing tmux plugins..."
    # install_plugins reads TMUX_PLUGIN_MANAGER_PATH from a running tmux server.
    # Start one if needed, and re-source the config to pick up TPM's env var.
    STARTED_TMUX=0
    if ! tmux ls >/dev/null 2>&1; then
        tmux new-session -d -s _bootstrap_tpm
        STARTED_TMUX=1
    fi
    tmux source-file "$HOME/.tmux.conf" >/dev/null 2>&1 || true
    "$TPM_DIR/bin/install_plugins"
    [ "$STARTED_TMUX" -eq 1 ] && tmux kill-session -t _bootstrap_tpm >/dev/null 2>&1 || true
    log_info "tmux plugins up to date"
fi

# --- Repo-local hook ---
if should_run LOCAL; then
    LOCAL_HOOK="$DOTFILES_DIR/bootstrap.local.sh"
    if [ -f "$LOCAL_HOOK" ]; then
        log_section "Local ($(basename "$DOTFILES_DIR"))"
        log_action "Running $LOCAL_HOOK..."
        # shellcheck disable=SC1090
        source "$LOCAL_HOOK"
        log_info "Local hook complete"
    fi
fi

printf "\n${BOLD}${GREEN}Bootstrap complete!${RESET}\n"
