#!/usr/bin/env bash
# Run the app on a connected Android phone or emulator.
#
#   ./scripts/run.sh                       # debug build against the production API
#   API_URL=https://staging.example ./scripts/run.sh --release
#
# Extra arguments are passed straight to `flutter run` (e.g. -d <device id>).

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$ROOT_DIR"

require_flutter
url="$(api_url)"
info "API: $url"
exec flutter run --dart-define="API_URL=$url" "$@"
