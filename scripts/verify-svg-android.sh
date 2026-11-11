#!/bin/sh
set -eu
# Invoke inside an android:elegant-fir-probe + resident_devices:1 reservation.
# The managed test runner also needs native_builds:1 while it compiles.
svg_serial=''
svg_owned=0
for candidate in $(adb devices | awk '/^emulator-.*device$/ {print $1}'); do
  svg_avd=$(adb -s "$candidate" emu avd name | head -1 | tr -d '\r')
  if [ "$svg_avd" != elegant-fir-probe ]; then
    echo "Another Android emulator is running: $candidate ($svg_avd)" >&2
    exit 1
  fi
  svg_serial=$candidate
done
cleanup() {
  if [ "$svg_owned" = 1 ]; then
    adb -s "$svg_serial" emu kill >/dev/null 2>&1 || true
    wait "$svg_pid" || true
  fi
}
trap cleanup EXIT INT TERM
if [ -z "$svg_serial" ]; then
  svg_serial=emulator-5582
  "${ANDROID_HOME:-$HOME/Library/Android/sdk}/emulator/emulator" \
    -avd elegant-fir-probe -port 5582 -no-window -no-audio -no-boot-anim \
    > /tmp/svg-import-emulator.log 2>&1 &
  svg_pid=$!
  svg_owned=1
fi
svg_attempt=0
until [ "$(adb -s "$svg_serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do
  if [ "$svg_owned" = 1 ] && ! kill -0 "$svg_pid" 2>/dev/null; then echo "Emulator exited; see /tmp/svg-import-emulator.log" >&2; exit 1; fi
  svg_attempt=$((svg_attempt + 1))
  if [ "$svg_attempt" -ge 120 ]; then echo 'Android boot timeout' >&2; exit 1; fi
  sleep 1
done
pnpm test:android --device "$svg_serial"
