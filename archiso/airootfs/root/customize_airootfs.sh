#!/usr/bin/env bash
set -e

# Compile GLib / GSettings schemas including 20_xenolinux.gschema.override
if [ -d /usr/share/glib-2.0/schemas ]; then
    glib-compile-schemas /usr/share/glib-2.0/schemas 2>/dev/null || true
fi

# Ensure liveuser home directory exists and is populated from /etc/skel
if [ -d /etc/skel ]; then
    mkdir -p /home/liveuser
    cp -rT /etc/skel /home/liveuser
    chown -R 1000:1000 /home/liveuser 2>/dev/null || true
fi
