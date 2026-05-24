#!/usr/bin/env python3
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
from gi.repository import Gtk, Gdk, GtkLayerShell
import subprocess
import sys
import math
import os

# Catppuccin Mocha
BG      = (0x1e/255, 0x1e/255, 0x2e/255, 0.97)
SURFACE = (0x31/255, 0x32/255, 0x44/255, 1.0)
OVERLAY = (0x45/255, 0x47/255, 0x5a/255, 1.0)
TEXT    = (0xcd/255, 0xd6/255, 0xf4/255, 1.0)
PURPLE  = (0xcb/255, 0xa6/255, 0xf7/255, 1.0)
BLUE    = (0x89/255, 0xb4/255, 0xfa/255, 1.0)
RED     = (0xf3/255, 0x8b/255, 0xa8/255, 1.0)
RED_BG  = (0xf3/255, 0x8b/255, 0xa8/255, 0.18)

W        = 400
PAD      = 12
ITEM_H   = 38
SLIDER_H = 48
HEADER_H = 34


class AudioPopup(Gtk.Window):
    def __init__(self, margin_left, margin_top):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.set_decorated(False)
        self.set_app_paintable(True)
        self.set_title('AudioSwitcher')

        # Layer shell — behaves like wofi (overlay, no tiling)
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, margin_top)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.LEFT, margin_left)
        GtkLayerShell.set_exclusive_zone(self, -1)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)

        # RGBA
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        self.volume       = self._get_volume()
        self.sinks, self.default_sink = self._get_sinks()
        self.hover_idx    = -1
        self.dragging     = False
        self.slider_rect  = None
        self.devices_y0   = 0

        n = len(self.sinks)
        self.total_h = PAD + HEADER_H + PAD + SLIDER_H + PAD + 1 + PAD + n * ITEM_H + PAD
        self.set_size_request(W, self.total_h)

        da = Gtk.DrawingArea()
        da.set_size_request(W, self.total_h)
        da.add_events(
            Gdk.EventMask.BUTTON_PRESS_MASK   |
            Gdk.EventMask.BUTTON_RELEASE_MASK |
            Gdk.EventMask.POINTER_MOTION_MASK |
            Gdk.EventMask.LEAVE_NOTIFY_MASK
        )
        da.connect('draw',                  self._draw)
        da.connect('button-press-event',    self._on_press)
        da.connect('button-release-event',  self._on_release)
        da.connect('motion-notify-event',   self._on_motion)
        da.connect('leave-notify-event',    self._on_leave)
        self.da = da
        self.add(da)

        self.connect('key-press-event',   self._on_key)
        self.connect('focus-out-event',   lambda *_: Gtk.main_quit())

        self.show_all()

    # ── data ─────────────────────────────────────────────────────────────────

    def _get_volume(self):
        try:
            out = subprocess.run(
                ['wpctl', 'get-volume', '@DEFAULT_AUDIO_SINK@'],
                capture_output=True, text=True
            ).stdout.strip()
            return min(float(out.split()[1]) * 100, 150.0)
        except Exception:
            return 50.0

    def _get_sinks(self):
        try:
            default = subprocess.run(
                ['pactl', 'get-default-sink'],
                capture_output=True, text=True
            ).stdout.strip()
            raw = subprocess.run(
                ['pactl', 'list', 'sinks'],
                capture_output=True, text=True
            ).stdout
        except Exception:
            return [], ''

        names_file = os.path.expanduser('~/.config/hypr/scripts/audio_names.conf')
        name_map = {}
        if os.path.exists(names_file):
            with open(names_file) as f:
                for line in f:
                    if '=' in line:
                        k, _, v = line.partition('=')
                        name_map[k.strip()] = v.strip()

        sinks, cur_name, cur_desc = [], '', ''
        for line in raw.splitlines():
            if line.startswith('\tName:'):
                cur_name = line.split(None, 1)[1]
            elif line.startswith('\tDescription:'):
                cur_desc = line.split(None, 1)[1]
                sinks.append((cur_name, name_map.get(cur_desc, cur_desc)))
        return sinks, default

    # ── drawing ───────────────────────────────────────────────────────────────

    def _draw(self, widget, cr):
        w, h = W, self.total_h

        cr.set_source_rgba(*BG)
        self._rrect(cr, 0, 0, w, h, 12)
        cr.fill()

        cr.set_source_rgba(*PURPLE)
        cr.set_line_width(1)
        self._rrect(cr, 0.5, 0.5, w - 1, h - 1, 12)
        cr.stroke()

        y = PAD

        # Header
        cr.set_source_rgba(*TEXT)
        cr.select_font_face('JetBrainsMono Nerd Font', 0, 1)
        cr.set_font_size(13)
        cr.move_to(PAD + 4, y + 22)
        cr.show_text(' Audio')
        y += HEADER_H + PAD

        # Slider
        self._draw_slider(cr, PAD, y, w - PAD * 2, SLIDER_H)
        y += SLIDER_H + PAD

        # Separator
        cr.set_source_rgba(*OVERLAY[:3], 0.5)
        cr.rectangle(PAD, y, w - PAD * 2, 1)
        cr.fill()
        y += 1 + PAD

        self.devices_y0 = y

        # Device list
        for i, (name, label) in enumerate(self.sinks):
            is_default = name == self.default_sink
            is_hover   = i == self.hover_idx

            if is_hover:
                cr.set_source_rgba(*OVERLAY[:3], 0.8)
                self._rrect(cr, PAD, y + 1, w - PAD * 2, ITEM_H - 2, 6)
                cr.fill()
            elif is_default:
                cr.set_source_rgba(*SURFACE[:3], 0.9)
                self._rrect(cr, PAD, y + 1, w - PAD * 2, ITEM_H - 2, 6)
                cr.fill()

            if is_default:
                cr.set_source_rgba(*PURPLE)
                cr.select_font_face('JetBrainsMono Nerd Font', 0, 0)
                cr.set_font_size(12)
                cr.move_to(PAD + 8, y + ITEM_H // 2 + 5)
                cr.show_text('✓')

            cr.set_source_rgba(*TEXT)
            cr.select_font_face('JetBrainsMono Nerd Font', 0, 0)
            cr.set_font_size(13)
            cr.move_to(PAD + 28, y + ITEM_H // 2 + 5)
            cr.show_text(label[:44])
            y += ITEM_H

    def _draw_slider(self, cr, x, y, w, h):
        TRACK_H  = 6
        THUMB_R  = 8
        ty       = y + h // 2 - 6
        normal_w = int(w * 100 / 150)
        fill_w   = int(w * self.volume / 150)
        fill_x   = x + fill_w

        # Track – normal zone
        cr.set_source_rgba(*SURFACE)
        self._rrect(cr, x, ty - TRACK_H // 2, normal_w, TRACK_H, 3)
        cr.fill()

        # Track – danger zone
        cr.set_source_rgba(*RED_BG)
        self._rrect(cr, x + normal_w, ty - TRACK_H // 2, w - normal_w, TRACK_H, 3)
        cr.fill()

        # Fill
        if fill_w > 0:
            if fill_w <= normal_w:
                cr.set_source_rgba(*BLUE)
                self._rrect(cr, x, ty - TRACK_H // 2, fill_w, TRACK_H, 3)
                cr.fill()
            else:
                cr.set_source_rgba(*BLUE)
                self._rrect(cr, x, ty - TRACK_H // 2, normal_w, TRACK_H, 3)
                cr.fill()
                cr.set_source_rgba(*RED)
                self._rrect(cr, x + normal_w, ty - TRACK_H // 2, fill_w - normal_w, TRACK_H, 3)
                cr.fill()

        # Divider at 100%
        cr.set_source_rgba(1, 1, 1, 0.3)
        cr.set_line_width(1.5)
        cr.move_to(x + normal_w, ty - TRACK_H // 2 - 3)
        cr.line_to(x + normal_w, ty + TRACK_H // 2 + 3)
        cr.stroke()

        # Thumb
        cr.set_source_rgba(1, 1, 1, 0.95)
        cr.arc(fill_x, ty, THUMB_R, 0, 2 * math.pi)
        cr.fill()

        dot_color = RED if self.volume > 100 else BLUE
        cr.set_source_rgba(*dot_color[:3], 0.9)
        cr.arc(fill_x, ty, 3, 0, 2 * math.pi)
        cr.fill()

        # Labels below track
        label_y = ty + TRACK_H // 2 + 14
        cr.select_font_face('JetBrainsMono Nerd Font', 0, 0)
        cr.set_font_size(10)
        cr.set_source_rgba(*TEXT[:3], 0.45)

        cr.move_to(x, label_y)
        cr.show_text('0%')

        ext = cr.text_extents('100%')
        cr.move_to(x + normal_w - ext.width / 2, label_y)
        cr.show_text('100%')

        ext = cr.text_extents('150%')
        cr.move_to(x + w - ext.width, label_y)
        cr.show_text('150%')

        # Current volume label (top-right)
        vol_str = f'{int(self.volume)}%'
        cr.set_source_rgba(*(RED if self.volume > 100 else PURPLE))
        cr.select_font_face('JetBrainsMono Nerd Font', 0, 1)
        cr.set_font_size(12)
        ext = cr.text_extents(vol_str)
        cr.move_to(x + w - ext.width, ty - TRACK_H // 2 - 6)
        cr.show_text(vol_str)

        self.slider_rect = (x, y, w, h)

    def _rrect(self, cr, x, y, w, h, r):
        cr.arc(x + r,     y + r,     r, math.pi,         3 * math.pi / 2)
        cr.arc(x + w - r, y + r,     r, 3 * math.pi / 2, 0)
        cr.arc(x + w - r, y + h - r, r, 0,               math.pi / 2)
        cr.arc(x + r,     y + h - r, r, math.pi / 2,     math.pi)
        cr.close_path()

    # ── interaction ───────────────────────────────────────────────────────────

    def _vol_from_x(self, mx):
        sx, sy, sw, sh = self.slider_rect
        return max(0.0, min(150.0, (mx - sx) / sw * 150))

    def _on_press(self, widget, ev):
        if self.slider_rect:
            sx, sy, sw, sh = self.slider_rect
            if sx <= ev.x <= sx + sw and sy <= ev.y <= sy + sh:
                self.dragging = True
                self.volume = self._vol_from_x(ev.x)
                self._apply_volume()
                widget.queue_draw()
                return True

        if self.devices_y0:
            rel = ev.y - self.devices_y0
            if rel >= 0:
                idx = int(rel // ITEM_H)
                if 0 <= idx < len(self.sinks):
                    self._switch_sink(*self.sinks[idx])
        return True

    def _on_release(self, widget, ev):
        self.dragging = False

    def _on_motion(self, widget, ev):
        if self.dragging and self.slider_rect:
            self.volume = self._vol_from_x(ev.x)
            self._apply_volume()
            widget.queue_draw()
            return

        if self.devices_y0:
            rel = ev.y - self.devices_y0
            new = int(rel // ITEM_H) if rel >= 0 else -1
            if not (0 <= new < len(self.sinks)):
                new = -1
            if new != self.hover_idx:
                self.hover_idx = new
                widget.queue_draw()

    def _on_leave(self, widget, ev):
        if self.hover_idx != -1:
            self.hover_idx = -1
            widget.queue_draw()

    def _on_key(self, widget, ev):
        if ev.keyval == Gdk.KEY_Escape:
            Gtk.main_quit()

    def _apply_volume(self):
        subprocess.run(
            ['wpctl', 'set-volume', '--limit', '1.5',
             '@DEFAULT_AUDIO_SINK@', f'{self.volume / 100:.3f}'],
            capture_output=True
        )

    def _switch_sink(self, name, label):
        subprocess.run(['pactl', 'set-default-sink', name], capture_output=True)
        result = subprocess.run(
            ['pactl', 'list', 'sink-inputs', 'short'],
            capture_output=True, text=True
        )
        for line in result.stdout.splitlines():
            if line.strip():
                subprocess.run(
                    ['pactl', 'move-sink-input', line.split()[0], name],
                    capture_output=True
                )
        subprocess.run(
            ['notify-send', 'Audio', label, '--icon=audio-headphones', '-t', '2000']
        )
        self.default_sink = name
        self.da.queue_draw()


if __name__ == '__main__':
    margin_left = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    margin_top  = int(sys.argv[2]) if len(sys.argv) > 2 else 30

    win = AudioPopup(margin_left, margin_top)
    win.connect('destroy', Gtk.main_quit)
    Gtk.main()
