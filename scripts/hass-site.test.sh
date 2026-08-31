#!/usr/bin/env bash
# Self-check for hass-site.sh — asserts core behavior, then restores the machine's
# real symlink state. No framework. Run: scripts/hass-site.test.sh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
HS="$SCRIPT_DIR/hass-site.sh"

# Save current per-machine symlink state so the test is non-destructive.
save() { readlink "$ROOT/$1" 2>/dev/null || echo ""; }
ORIG_PKG="$(save packages/active)"; ORIG_APP="$(save app/active)"
restore() {
  [ -n "$ORIG_PKG" ] && ln -sfn "$ORIG_PKG" "$ROOT/packages/active" || rm -f "$ROOT/packages/active"
  [ -n "$ORIG_APP" ] && ln -sfn "$ORIG_APP" "$ROOT/app/active" || rm -f "$ROOT/app/active"
}
trap restore EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

# Pick a real site to test against (first available).
site="$("$HS" --list | head -1)"
[ -n "$site" ] || fail "no sites available to test"

# 1. Setting a valid site points BOTH symlinks at it.
"$HS" "$site" >/dev/null
[ "$(save packages/active)" = "site_$site" ] || fail "packages/active not set to site_$site"
[ "$(save app/active)" = "site_$site" ]      || fail "app/active not set to site_$site"

# 2. The site_ prefix is accepted and equivalent.
"$HS" "site_$site" >/dev/null
[ "$(save packages/active)" = "site_$site" ] || fail "site_ prefix form not handled"

# 3. Unknown site is rejected (non-zero) and does NOT change the symlinks.
before="$(save packages/active)"
if "$HS" definitely_not_a_site >/dev/null 2>&1; then fail "unknown site should exit non-zero"; fi
[ "$(save packages/active)" = "$before" ] || fail "unknown site must not modify symlinks"

echo "PASS: hass-site.sh (set both symlinks, prefix handling, reject unknown)"
