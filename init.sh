#!/bin/bash

set -e

DOTFILES_DIR=$(cd "$(dirname "$0")" && pwd -P)

# Ensure submodules are initialized and up to date
git -C "$DOTFILES_DIR" submodule update --init --recursive
git -C "$DOTFILES_DIR/shared" checkout main
git -C "$DOTFILES_DIR/shared" branch --set-upstream-to=origin/main