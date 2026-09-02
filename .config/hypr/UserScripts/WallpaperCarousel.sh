#!/usr/bin/env bash
# Rofi script-mode source for SUPER+W (see man rofi-script(5)).
# Reprints a fixed-size window of entries around a tracked center index on
# every Left/Right custom keybinding press, giving a sliding-carousel feel
# that rofi's native listview scrolling (page-based) can't do.

list_file="${WALL_CAROUSEL_LIST:?}"
result_file="${WALL_CAROUSEL_RESULT:?}"
half=2 # neighbours shown on each side => 2*half+1 = 5 visible slots

mapfile -t PICS <"$list_file"
total=${#PICS[@]}
[[ $total -eq 0 ]] && exit 0

if [[ -n "${ROFI_DATA:-}" ]]; then
  center=$ROFI_DATA
else
  center=${WALL_CAROUSEL_START:-0}
fi
center=$(((center % total + total) % total))

live_preview() {
  local target="$1"
  case "$target" in
  *.mp4 | *.mkv | *.mov | *.webm | *.MP4 | *.MKV | *.MOV | *.WEBM) return ;;
  esac
  pgrep -x swww-daemon >/dev/null || coproc (swww-daemon --format xrgb >/dev/null 2>&1)
  coproc (swww img "$target" --transition-type none >/dev/null 2>&1)
}

case "${ROFI_RETV:-0}" in
1)
  printf '%s' "${PICS[$center]}" >"$result_file"
  exit 0
  ;;
10) center=$(((center - 1 + total) % total)) ;; # Left
11) center=$(((center + 1) % total)) ;;          # Right
esac

live_preview "${PICS[$center]}"

printf '\0use-hot-keys\x1ftrue\n'
printf '\0keep-selection\x1ftrue\n'
printf '\0new-selection\x1f%s\n' "$half"
printf '\0data\x1f%s\n' "$center"

for ((i = -half; i <= half; i++)); do
  idx=$((((center + i) % total + total) % total))
  pic_path="${PICS[$idx]}"
  pic_name=$(basename "$pic_path")
  label="${pic_name%.*}"
  printf '%s\0icon\x1f%s\n' "$label" "$pic_path"
done
