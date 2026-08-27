#!/usr/bin/env bash
# Script for oh-my-posh theme picker ( SUPER SHIFT O)
# Browses ~/.poshthemes and updates the oh-my-posh init line in
# ~/.config/fish/conf.d/20-customization.fish (the shell actually in use)

# Variables
iDIR="$HOME/.config/swaync/images"
rofi_theme="$HOME/.config/rofi/config-zsh-theme.rasi"

themes_dir="$HOME/.poshthemes"

if [ ! -d "$themes_dir" ]; then
    notify-send -i "$iDIR/error.png" "E-R-R-O-R" "$themes_dir not found!"
    exit 1
fi

themes_array=($(find -L "$themes_dir" -maxdepth 1 -type f \( -name "*.omp.json" -o -name "*.omp.yaml" \) -exec basename {} \; | sort))

# Add "Random" option to the beginning of the array
themes_array=("Random" "${themes_array[@]}")

rofi_command="rofi -i -dmenu -config $rofi_theme"

menu() {
    for theme in "${themes_array[@]}"; do
        echo "$theme"
    done
}

main() {
    choice=$(menu | ${rofi_command})

    # if nothing selected, script won't change anything
    if [ -z "$choice" ]; then
        exit 0
    fi

    customization_file="$HOME/.config/fish/conf.d/20-customization.fish"

    if [[ "$choice" == "Random" ]]; then
        # Pick a random theme from the original themes_array (excluding "Random")
        random_theme=${themes_array[$((RANDOM % (${#themes_array[@]} - 1) + 1))]}
        theme_to_set="$random_theme"
        notify-send -i "$iDIR/ja.png" "Random theme:" "selected: $random_theme"
    else
        # Set theme to the selected choice
        theme_to_set="$choice"
        notify-send -i "$iDIR/ja.png" "Theme selected:" "$choice"
    fi

    if [ -f "$customization_file" ]; then
        new_line="eval \"\$(\$HOME/.local/bin/oh-my-posh init fish --config $themes_dir/$theme_to_set)\""
        if grep -q '^eval "\$(\$HOME/.local/bin/oh-my-posh init fish' "$customization_file"; then
            # Replace the existing active line in place
            sed -i "0,/^eval \"\\\$(\\\$HOME\\/.local\\/bin\\/oh-my-posh init fish/s|^eval \"\\\$(\\\$HOME/.local/bin/oh-my-posh init fish.*|$new_line|" "$customization_file"
        else
            printf '\n%s\n' "$new_line" >> "$customization_file"
        fi
        notify-send -i "$iDIR/ja.png" "oh-my-posh theme" "applied. restart your terminal"
    else
        notify-send -i "$iDIR/error.png" "E-R-R-O-R" "$customization_file not found!"
    fi
}

# Check if rofi is already running
if pidof rofi > /dev/null; then
  pkill rofi
fi

main
