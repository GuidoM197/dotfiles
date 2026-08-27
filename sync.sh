#!/bin/bash
# Actualiza el repo con la config actual del sistema
set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

configs=(hypr waybar rofi swaync)

for cfg in "${configs[@]}"; do
    echo "Sincronizando $cfg..."
    rsync -a --delete \
        "$HOME/.config/$cfg/" \
        "$DOTFILES/.config/$cfg/"
done

echo ""
echo "Listo. Revisar cambios con: git diff"
echo "Guardar snapshot con:       git add -A && git commit -m 'snapshot: \$(date +%Y-%m-%d)'"
