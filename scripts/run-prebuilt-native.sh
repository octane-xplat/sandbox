#!/bin/bash
# Invoke inside the matching device resource reservation, after test-build compilation.
set -euo pipefail
platform=$1
owned=0
serial=''
cleanup() {
  if [[ "$platform" == ios ]]; then
    xcrun simctl terminate "$NS_DEVICE" org.octanexplat.fittext >/dev/null 2>&1 || true
    if [[ "$owned" == 1 ]]; then xcrun simctl shutdown "$NS_DEVICE"; fi
  elif [[ "$owned" == 1 && -n "$serial" ]]; then
    adb -s "$serial" emu kill >/dev/null 2>&1 || true
    wait "$emulator_pid" || true
  else
    adb -s "$serial" shell am force-stop org.octanexplat.fittext >/dev/null 2>&1 || true
  fi
}
export NS_PLATFORM="$platform" NS_PREBUILT=1
if [[ "$platform" == ios ]]; then
  export NS_DEVICE=91D40099-A056-497D-A572-ADDDFD6A8F23
  state=$(xcrun simctl list devices --json | python3 -c 'import json,sys; d=[d for ds in json.load(sys.stdin)["devices"].values() for d in ds if d["udid"]=="91D40099-A056-497D-A572-ADDDFD6A8F23"]; print(d[0]["state"] if d else "Missing")')
  if [[ "$state" == Missing ]]; then echo 'Required iOS simulator is missing'; exit 1; fi
  trap cleanup EXIT
  if [[ "$state" != Booted ]]; then
    xcrun simctl boot "$NS_DEVICE"
    owned=1
  fi
  xcrun simctl bootstatus "$NS_DEVICE" -b
  app_path=$(find platforms/ios/build -name sandbox.app -type d -print -quit)
  if [[ -z "$app_path" ]]; then echo 'Prebuilt iOS app missing'; exit 1; fi
  xcrun simctl install "$NS_DEVICE" "$app_path"
elif [[ "$platform" == android ]]; then
  adb start-server
  serial=$(adb devices | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1; exit }')
  if [[ -n "$serial" ]]; then
    avd=$(adb -s "$serial" emu avd name | head -1 | tr -d '\r')
    if [[ "$avd" != elegant-fir-probe ]]; then echo "Another AVD is already running: $avd"; exit 1; fi
  else
    if adb devices | awk '$1 ~ /^emulator-/ { found=1 } END { exit !found }'; then echo 'An emulator is starting/offline; refusing another instance'; exit 1; fi
    "$HOME/Library/Android/sdk/emulator/emulator" -avd elegant-fir-probe -no-window -no-audio -no-snapshot-save -no-boot-anim > /tmp/avid-emulator.log 2>&1 &
    emulator_pid=$!
    owned=1
    for ((i=0; i<120; i++)); do
      serial=$(adb devices | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1; exit }')
      if [[ -n "$serial" ]]; then break; fi
      sleep 1
    done
    if [[ -z "$serial" ]]; then kill "$emulator_pid"; echo 'Emulator failed to boot'; exit 1; fi
  fi
  export NS_DEVICE="$serial"
  trap cleanup EXIT
  for ((i=0; i<120; i++)); do
    if [[ "$(adb -s "$serial" shell getprop sys.boot_completed | tr -d '\r')" == 1 ]]; then break; fi
    sleep 1
  done
  apk_path=$(find platforms/android/app/build/outputs/apk -name '*.apk' -print -quit)
  adb -s "$serial" install -r "$apk_path"
else
  echo 'Use ios or android'; exit 1
fi
pnpm exec vitest run --config vitest.config.mts
