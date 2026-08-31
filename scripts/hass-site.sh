#!/usr/bin/env bash
# hass-site — select this machine's Home Assistant site.
#
# Points BOTH per-machine symlinks at one site package:
#   packages/active -> packages/site_<name>    (backend)
#   app/active      -> app/site_<name>          (UI)
# Both symlinks are gitignored (per-machine). See packages/README.md.
#
# Usage:
#   scripts/hass-site.sh <site>     # e.g. 841n4th  (the site_ prefix is optional)
#   scripts/hass-site.sh            # show current selection + available sites
#   scripts/hass-site.sh --list     # list available sites
#
# As a shell function (add to ~/.zshrc or ~/.bashrc):
#   hass-site() { "/path/to/config/scripts/hass-site.sh" "$@"; }

set -euo pipefail

# Repo root = parent of this script's dir, so it works from anywhere.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

list_sites() {
  # A site is valid only if it exists under BOTH packages/ and app/.
  for d in "$ROOT"/packages/site_*/; do
    [ -d "$d" ] || continue
    local name="${d%/}"; name="${name##*/site_}"
    [ -d "$ROOT/app/site_$name" ] && echo "$name"
  done
}

show_current() {
  local p a
  p="$(readlink "$ROOT/packages/active" 2>/dev/null || echo '(unset)')"
  a="$(readlink "$ROOT/app/active" 2>/dev/null || echo '(unset)')"
  echo "current: packages/active -> $p"
  echo "         app/active      -> $a"
  [ "$p" = "$a" ] || echo "WARNING: the two symlinks point at DIFFERENT sites." >&2
  echo "available sites:"; list_sites | sed 's/^/  - /'
}

main() {
  case "${1:-}" in
    ""|-s|--show)   show_current; exit 0 ;;
    -l|--list)      list_sites; exit 0 ;;
    -h|--help)      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac

  # Accept either "841n4th" or "site_841n4th".
  local site="${1#site_}"

  if [ ! -d "$ROOT/packages/site_$site" ] || [ ! -d "$ROOT/app/site_$site" ]; then
    echo "error: unknown site '$site'." >&2
    echo "must exist as BOTH packages/site_$site and app/site_$site." >&2
    echo "available:"; list_sites | sed 's/^/  - /' >&2
    exit 1
  fi

  # -n so we replace the symlink itself rather than following it into the target.
  ln -sfn "site_$site" "$ROOT/packages/active"
  ln -sfn "site_$site" "$ROOT/app/active"

  echo "site set to '$site':"
  show_current
  echo
  echo "next: ensure secrets.yaml matches this site, then: ha core check && ha core restart"
}

main "$@"
