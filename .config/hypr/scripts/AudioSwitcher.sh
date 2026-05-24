#!/bin/bash

SCRIPT_DIR="$HOME/.config/hypr/scripts"

cursor=$(hyprctl cursorpos)
cx=$(echo "$cursor" | cut -d',' -f1 | tr -d ' ')

bar_bottom=$(hyprctl layers -j | python3 -c "
import sys, json
layers = json.load(sys.stdin)
for monitor, data in layers.items():
    for level, items in data.get('levels', {}).items():
        for item in items:
            if item.get('namespace','') == 'waybar':
                print(item['y'] + item['h'])
                exit()
" 2>/dev/null)

wx=$((cx - 200))
wy=${bar_bottom:-30}

python3 "$SCRIPT_DIR/audio_switcher.py" "$wx" "$wy"
