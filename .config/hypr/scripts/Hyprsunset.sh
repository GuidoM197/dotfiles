#!/usr/bin/env bash

STATE_FILE="$HOME/.cache/.hyprsunset_state"
TARGET_TEMP="${HYPRSUNSET_TEMP:-4500}"

ensure_state() {
  [[ -f "$STATE_FILE" ]] || echo "off" > "$STATE_FILE"
}

icon_off() { printf "☀"; }
icon_on()  { printf "🌙"; }

cmd_toggle() {
  ensure_state
  state="$(cat "$STATE_FILE")"

  pkill -x hyprsunset 2>/dev/null || true

  if [[ "$state" == "on" ]]; then
    echo "off" > "$STATE_FILE"
    notify-send -u low "Hyprsunset: Desactivado" || true
  else
    sleep 0.1
    nohup hyprsunset -t "$TARGET_TEMP" >/dev/null 2>&1 &
    disown
    echo "on" > "$STATE_FILE"
    notify-send -u low "Hyprsunset: Activado" "${TARGET_TEMP}K" || true
  fi

  pkill -RTMIN+8 waybar || true
}

cmd_status() {
  ensure_state
  state="$(cat "$STATE_FILE")"

  if [[ "$state" == "on" ]]; then
    printf '{"text":"%s","class":"on","tooltip":"Modo noche activo @ %sK"}\n' \
      "$(icon_on)" "$TARGET_TEMP"
  else
    printf '{"text":"<span size='\''16pt'\''>%s</span>","class":"off","tooltip":"Modo noche desactivado"}\n' \
      "$(icon_off)"
  fi
}

cmd_init() {
  ensure_state
  if [[ "$(cat "$STATE_FILE")" == "on" ]]; then
    nohup hyprsunset -t "$TARGET_TEMP" >/dev/null 2>&1 &
    disown
  fi
}

case "${1:-}" in
  toggle) cmd_toggle ;;
  status) cmd_status ;;
  init)   cmd_init ;;
  *) echo "uso: $0 [toggle|status|init]" >&2; exit 2 ;;
esac
