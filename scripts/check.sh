#!/usr/bin/env bash
# Quality gate: static analysis and unit/widget tests (fatal), plus a formatting check (advisory
# unless STRICT_FORMAT=1).
#
#   ./scripts/check.sh            # everything
#   ./scripts/check.sh --fix      # also rewrite formatting in place
#   STRICT_FORMAT=1 ./scripts/check.sh

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$ROOT_DIR"

require_flutter
fix=0
[[ "${1:-}" == "--fix" ]] && fix=1

info "Fetching packages"
flutter pub get >/dev/null

if (( fix )); then
  info "Formatting"
  dart format --line-length 120 lib test
else
  info "Checking formatting"
  if ! dart format --line-length 120 --output=none --set-exit-if-changed lib test; then
    if [[ "${STRICT_FORMAT:-0}" == "1" ]]; then
      die "Formatting differs. Run ./scripts/check.sh --fix"
    fi
    warn "Formatting differs from dart format. Run ./scripts/check.sh --fix (not fatal)."
  fi
fi

info "Analysing"
flutter analyze --no-fatal-infos

info "Running tests"
flutter test --reporter expanded

info "All checks passed"
