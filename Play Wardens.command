#!/bin/zsh
# Double-click to play WARDENS.
cd "$(dirname "$0")"
exec /opt/homebrew/bin/godot --path . "$@"
