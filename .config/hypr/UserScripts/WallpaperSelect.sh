#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */
# This script for selecting wallpapers (SUPER W)

# WALLPAPERS PATH
terminal=kitty
PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallDIR="$PICTURES_DIR/wallpapers"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"

# Directory for swaync
iDIR="$HOME/.config/swaync/images"
iDIRi="$HOME/.config/swaync/icons"

# swww transition config
FPS=60
TYPE="any"
DURATION=2
BEZIER=".43,1.19,1,.4"
SWWW_PARAMS="--transition-fps $FPS --transition-type $TYPE --transition-duration $DURATION --transition-bezier $BEZIER"

# Check if package bc exists
if ! command -v bc &>/dev/null; then
  notify-send -i "$iDIR/error.png" "bc missing" "Install package bc first"
  exit 1
fi

# Variables
rofi_theme="$HOME/.config/rofi/config-wallpaper.rasi"
focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')

# Ensure focused_monitor is detected
if [[ -z "$focused_monitor" ]]; then
  notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Could not detect focused monitor"
  exit 1
fi

# Monitor details
scale_factor=$(hyprctl monitors -j | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .scale')
monitor_height=$(hyprctl monitors -j | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .height')

icon_size=$(echo "scale=1; ($monitor_height * 3) / ($scale_factor * 150)" | bc)
adjusted_icon_size=$(echo "$icon_size" | awk '{if ($1 < 15) $1 = 20; if ($1 > 25) $1 = 25; print $1}')
rofi_override="element-icon{size:${adjusted_icon_size}%;}"

# Kill existing wallpaper daemons for video
kill_wallpaper_for_video() {
  swww kill 2>/dev/null
  pkill mpvpaper 2>/dev/null
  pkill swaybg 2>/dev/null
  pkill hyprpaper 2>/dev/null
}

# Kill existing wallpaper daemons for image
kill_wallpaper_for_image() {
  pkill mpvpaper 2>/dev/null
  pkill swaybg 2>/dev/null
  pkill hyprpaper 2>/dev/null
}

# Retrieve wallpapers (both images & videos)
mapfile -d '' PICS < <(find -L "${wallDIR}" -type f \( \
  -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o \
  -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.webp" -o \
  -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.webm" \) -print0)

# Sort wallpapers and hand them to WallpaperCarousel.sh (rofi script-mode
# modi) via a temp file - it drives the sliding-carousel display itself.
IFS=$'\n' sorted_pics=($(sort <<<"${PICS[*]}"))
unset IFS

if [[ ${#sorted_pics[@]} -eq 0 ]]; then
  notify-send -i "$iDIR/error.png" "E-R-R-O-R" "No wallpapers found in $wallDIR"
  exit 1
fi

carousel_list_file=$(mktemp /tmp/wallpaper_carousel_list.XXXXXX)
carousel_result_file=$(mktemp /tmp/wallpaper_carousel_result.XXXXXX)
printf '%s\n' "${sorted_pics[@]}" >"$carousel_list_file"
trap 'rm -f "$carousel_list_file" "$carousel_result_file"' EXIT

# Wallpaper active before opening the picker: restored if the user cancels
# (Esc), and used to open the carousel centered on the current wallpaper.
original_wallpaper=$(swww query 2>/dev/null | awk -F'image: ' '/image:/{print $2; exit}')
start_index=0
for i in "${!sorted_pics[@]}"; do
  if [[ "${sorted_pics[$i]}" == "$original_wallpaper" ]]; then
    start_index=$i
    break
  fi
done

export WALL_CAROUSEL_LIST="$carousel_list_file"
export WALL_CAROUSEL_RESULT="$carousel_result_file"
export WALL_CAROUSEL_START="$start_index"
carousel_script="$HOME/.config/hypr/UserScripts/WallpaperCarousel.sh"

# Left/Right default to moving the text cursor in the search box
# (kb-move-char-back/forward); free them up and rebind to the custom
# keybindings WallpaperCarousel.sh reads (RETV 10/11) for carousel sliding.
# -selected-row: on the very first frame rofi has no "previous selection" to
# keep, so the script's own new-selection header is ignored and it defaults
# to row 0 (leftmost) - this flag forces the initial highlight to the middle
# slot (index 2 of the 5 WallpaperCarousel.sh prints) independent of that.
rofi_cmd=(
  rofi -show wallpaper-carousel -modes "wallpaper-carousel:$carousel_script"
  -config "$rofi_theme" -theme-str "$rofi_override"
  -kb-move-char-back "Control+b" -kb-move-char-forward "Control+f"
  -kb-custom-1 "Left" -kb-custom-2 "Right"
  -selected-row 2
)


modify_startup_config() {
  local selected_file="$1"
  local startup_config="$HOME/.config/hypr/UserConfigs/Startup_Apps.conf"

  # Check if it's a live wallpaper (video)
  if [[ "$selected_file" =~ \.(mp4|mkv|mov|webm)$ ]]; then
    # For video wallpapers:
    sed -i '/^\s*exec-once\s*=\s*swww-daemon\s*--format\s*xrgb\s*$/s/^/\#/' "$startup_config"
    sed -i '/^\s*#\s*exec-once\s*=\s*mpvpaper\s*.*$/s/^#\s*//;' "$startup_config"

    # Update the livewallpaper variable with the selected video path (using $HOME)
    selected_file="${selected_file/#$HOME/\$HOME}" # Replace /home/user with $HOME
    sed -i "s|^\$livewallpaper=.*|\$livewallpaper=\"$selected_file\"|" "$startup_config"

    echo "Configured for live wallpaper (video)."
  else
    # For image wallpapers:
    sed -i '/^\s*#\s*exec-once\s*=\s*swww-daemon\s*--format\s*xrgb\s*$/s/^\s*#\s*//;' "$startup_config"

    sed -i '/^\s*exec-once\s*=\s*mpvpaper\s*.*$/s/^/\#/' "$startup_config"

    echo "Configured for static wallpaper (image)."
  fi
}

# Apply Image Wallpaper
apply_image_wallpaper() {
  local image_path="$1"

  kill_wallpaper_for_image

  if ! pgrep -x "swww-daemon" >/dev/null; then
    echo "Starting swww-daemon..."
    swww-daemon --format xrgb &
  fi

  swww img "$image_path" $SWWW_PARAMS

  # Run additional scripts (pass the image path to avoid cache race conditions)
  "$SCRIPTSDIR/WallustSwww.sh" "$image_path"
  sleep 2
  "$SCRIPTSDIR/Refresh.sh"
  sleep 1

}

apply_video_wallpaper() {
  local video_path="$1"

  # Check if mpvpaper is installed
  if ! command -v mpvpaper &>/dev/null; then
    notify-send -i "$iDIR/error.png" "E-R-R-O-R" "mpvpaper not found"
    return 1
  fi
  kill_wallpaper_for_video

  # Apply video wallpaper using mpvpaper
  mpvpaper '*' -o "load-scripts=no no-audio --loop" "$video_path" &
}

# Main function
main() {
  "${rofi_cmd[@]}"

  if [[ ! -s "$carousel_result_file" ]]; then
    echo "Cancelled. Restoring original wallpaper."
    [[ -n "$original_wallpaper" ]] && swww img "$original_wallpaper" $SWWW_PARAMS
    exit 0
  fi

  selected_file=$(<"$carousel_result_file")

  if [[ -z "$selected_file" || ! -f "$selected_file" ]]; then
    echo "File not found. Selected choice: $selected_file"
    [[ -n "$original_wallpaper" ]] && swww img "$original_wallpaper" $SWWW_PARAMS
    exit 1
  fi

  # Modify the Startup_Apps.conf file based on wallpaper type
  modify_startup_config "$selected_file"

  # **CHECK FIRST** if it's a video or an image **before calling any function**
  if [[ "$selected_file" =~ \.(mp4|mkv|mov|webm|MP4|MKV|MOV|WEBM)$ ]]; then
    apply_video_wallpaper "$selected_file"
  else
    apply_image_wallpaper "$selected_file"
  fi
}

# Check if rofi is already running
if pidof rofi >/dev/null; then
  pkill rofi
fi

main