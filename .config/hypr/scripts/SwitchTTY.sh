#!/bin/bash
VT="${1}"
gdbus call --system \
    --dest org.freedesktop.login1 \
    --object-path /org/freedesktop/login1/seat/seat0 \
    --method org.freedesktop.login1.Seat.SwitchTo \
    "${VT}" 2>/dev/null
