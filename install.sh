#!/bin/bash
# Restaura la config desde el repo al sistema
set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

# Paquetes referenciados por los scripts/configs de este repo (hypr, waybar,
# rofi, swaync). Detectados escaneando exec-once, keybinds y comandos de
# botones/módulos. Todos están en repos oficiales/CachyOS salvo wallust (AUR).
pacman_pkgs=(
    hyprland waybar rofi swaync
    hypridle hyprlock hyprpicker hyprsunset
    grim slurp swappy cliphist wlogout
    blueman playerctl pamixer brightnessctl
    nwg-look udiskie kitty network-manager-applet
    jq socat awww polkit-gnome
)
aur_pkgs=(wallust)

install_deps() {
    echo "Instalando dependencias (pacman)..."
    sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}"

    if [ ${#aur_pkgs[@]} -gt 0 ]; then
        local aur_helper=""
        if command -v yay >/dev/null 2>&1; then
            aur_helper="yay"
        elif command -v paru >/dev/null 2>&1; then
            aur_helper="paru"
        fi

        if [ -n "$aur_helper" ]; then
            echo "Instalando dependencias AUR ($aur_helper)..."
            "$aur_helper" -S --needed --noconfirm "${aur_pkgs[@]}"
        else
            echo "Aviso: no se encontró yay ni paru. Instalá manualmente: ${aur_pkgs[*]}"
        fi
    fi
}

configs=(hypr waybar rofi swaync)

restore_configs() {
    for cfg in "${configs[@]}"; do
        echo "Restaurando $cfg..."
        mkdir -p "$HOME/.config/$cfg"
        rsync -a --delete \
            "$DOTFILES/.config/$cfg/" \
            "$HOME/.config/$cfg/"
    done
}

if [ "$1" == "--skip-deps" ]; then
    echo "Saltando instalación de dependencias (--skip-deps)."
else
    install_deps
fi

restore_configs

echo ""
echo "Restaurado. Recargá Hyprland con: hyprctl reload"
