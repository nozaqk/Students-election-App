#!/usr/bin/env bash
# Build the Android APK.
#
#   ./scripts/build_apk.sh                      # release APK, production API, universal ABI
#   API_URL=https://... ./scripts/build_apk.sh  # point the app at another backend
#   ./scripts/build_apk.sh --debug              # debug APK (no shrinking, debuggable)
#   ./scripts/build_apk.sh --split              # one APK per ABI (smaller downloads)
#
# Release signing: create android/key.properties (see android/app/build.gradle). Without it the
# release APK is signed with the debug key, which still installs fine for side-loading.
#
# Build metadata: BUILD_NUMBER (versionCode) and BUILD_NAME (versionName) override pubspec.yaml.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$ROOT_DIR"

mode="release"
split=0
for arg in "$@"; do
  case "$arg" in
    --debug)   mode="debug" ;;
    --release) mode="release" ;;
    --split)   split=1 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) die "unknown option: $arg" ;;
  esac
done

require_flutter
url="$(api_url)"
info "API: $url"
info "Mode: $mode"

args=(build apk "--$mode" --dart-define="API_URL=$url")
[[ -n "${BUILD_NUMBER:-}" ]] && args+=(--build-number="$BUILD_NUMBER")
[[ -n "${BUILD_NAME:-}" ]]   && args+=(--build-name="$BUILD_NAME")
(( split )) && args+=(--split-per-abi)

flutter pub get >/dev/null
flutter "${args[@]}"

out_dir="build/app/outputs/flutter-apk"
info "APK(s):"
ls -1 "$out_dir"/*.apk | while read -r f; do
  size="$(du -h "$f" | cut -f1)"
  printf '   %s  (%s)\n' "$f" "$size"
done

if [[ -f "$out_dir/app-$mode.apk" ]]; then
  cp "$out_dir/app-$mode.apk" "$ROOT_DIR/election-app.apk"
  info "Copied to election-app.apk"
fi
