#!/usr/bin/env bash
# Shared helpers for the scripts in this folder. Source it; do not run it.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_API_URL="https://students-election-system.onrender.com"

info()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

require_flutter() {
  command -v flutter >/dev/null 2>&1 || die "Flutter is not on your PATH. Install it from https://docs.flutter.dev/get-started/install and run again."
  local version
  version="$(flutter --version --machine 2>/dev/null | sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p' | head -n1 || true)"
  if [[ -n "$version" ]]; then info "Flutter $version"; fi
}

# API base URL for the build: $API_URL env var, else the production default.
api_url() {
  local url="${API_URL:-$DEFAULT_API_URL}"
  url="${url%/}"
  [[ "$url" == https://* ]] || die "API_URL must start with https:// (got: $url)"
  printf '%s' "$url"
}
