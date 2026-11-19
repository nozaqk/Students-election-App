#!/usr/bin/env bash
# One-time developer setup: fetch Dart packages and make sure the Android toolchain is wired up.
#
#   ./scripts/setup.sh

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$ROOT_DIR"

require_flutter
info "Fetching packages"
flutter pub get

if [[ ! -f android/local.properties ]]; then
  # Flutter normally writes this file on first build; create it now so IDEs pick up the SDK paths.
  flutter_root="$(dirname "$(dirname "$(command -v flutter)")")"
  {
    echo "flutter.sdk=$flutter_root"
    [[ -n "${ANDROID_HOME:-}" ]] && echo "sdk.dir=$ANDROID_HOME"
    [[ -z "${ANDROID_HOME:-}" && -n "${ANDROID_SDK_ROOT:-}" ]] && echo "sdk.dir=$ANDROID_SDK_ROOT"
  } > android/local.properties || true
  info "Wrote android/local.properties"
fi

info "Checking the toolchain"
flutter doctor -v | sed -n '1,40p' || true

cat <<MSG

Ready. Useful commands:
  ./scripts/run.sh                 # run on a connected phone (debug)
  ./scripts/check.sh               # format, analyse and test
  ./scripts/build_apk.sh           # release APK against $DEFAULT_API_URL
  API_URL=https://... ./scripts/build_apk.sh
MSG
