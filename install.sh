#!/bin/bash
# Restaura la config desde el repo al sistema
set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

configs=(hypr waybar)

for cfg in "${configs[@]}"; do
    echo "Restaurando $cfg..."
    mkdir -p "$HOME/.config/$cfg"
    rsync -a --delete \
        "$DOTFILES/.config/$cfg/" \
        "$HOME/.config/$cfg/"
done

echo ""
echo "Restaurado. Recargá Hyprland con: hyprctl reload"
