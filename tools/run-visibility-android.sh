#!/usr/bin/env bash
# Run only inside an Android resource reservation for elegant-fir-probe.
set -eu
serial=emulator-5554
started=0
finish() {
  if [ "$started" = 1 ]; then adb -s "$serial" emu kill >/dev/null 2>&1 || true; fi
}
trap finish EXIT INT TERM
existing=$(adb devices | awk '/^emulator-/{print $1}')
if [ -n "$existing" ]; then
  if [ "$existing" != "$serial" ]; then
    echo 'An unexpected emulator is running; refusing to launch another.' >&2
    exit 1
  fi
  avd=$(adb -s "$serial" emu avd name | tr -d '\r' | head -1)
  if [ "$avd" != elegant-fir-probe ]; then
    echo 'Running emulator is not elegant-fir-probe.' >&2
    exit 1
  fi
else
  "${ANDROID_HOME:-$HOME/Library/Android/sdk}/emulator/emulator" -avd elegant-fir-probe -port 5554 -no-window -no-audio -no-boot-anim -no-snapshot-save > /tmp/text-visibility-emulator.log 2>&1 &
  started=1
fi
for ((attempt=0; attempt<90; attempt++)); do
  if [ "$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; then
    pnpm test:android --device "$serial"
    exit $?
  fi
  sleep 2
done
echo 'Authorized emulator did not finish booting within 180 seconds.' >&2
exit 1
