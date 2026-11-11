#!/bin/sh
# Запуск снимка под виртуальным экраном: tools/b_smoke/shot.sh out.png [секунды] [сценарий]
cd "$(dirname "$0")/../.." && timeout 200 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
  res://tools/b_smoke/Shot.tscn -- "$@" 2>&1 | grep -v -E "ALSA|audio_driver|audio_server|dummy driver|V-Sync|gl_manager|^$"
