#!/usr/bin/env bash
# List the third-party inputs and fail when one is outside the licence allow-list.
#
#   ./scripts/checks/check_licenses.sh
#
# The project has no package manager that an audit job can query: the tests restore NuGet
# packages through tracked packages.config files, and the Python binding downloads a pinned
# pybind11 archive with a batch script. The inventory below is maintained by hand and is the
# place where each input's licence is recorded; every package id in a tracked packages.config
# must also appear here, so a new NuGet package cannot slip past the check.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit

ALLOWED="MIT BSD-2-Clause BSD-3-Clause Apache-2.0 ISC Zlib Unlicense CC0-1.0 0BSD Python-2.0 BlueOak-1.0.0"

inventory() {
  cat <<'EOF'
Microsoft.googletest.v140.windesktop.msvcstl.static.rt-dyn|1.8.1.7|MIT|tests/core_tests/packages.config, tests/dll_tests/packages.config
pybind11|2.13.6|BSD-3-Clause|examples/python_binding/DownloadPybind11.bat
EOF
}

printf '%-66s %-9s %s\n' PACKAGE VERSION LICENSE
fail=0
table_ids=""
while IFS='|' read -r name version license source; do
  [ -n "$name" ] || continue
  table_ids="$table_ids $name"
  printf '%-66s %-9s %s\n' "$name" "$version" "$license"
  case " $ALLOWED " in
    *" $license "*) ;;
    *)
      printf 'FAIL %s %s is licensed %s, which the allow-list does not include\n' "$name" "$version" "$license"
      fail=1
      ;;
  esac
  echo "     from $source"
done < <(inventory)

configs="$(git ls-files -- '*packages.config')" || {
  echo "FAIL git ls-files could not list tracked packages.config files"
  exit 1
}
while IFS= read -r config; do
  [ -n "$config" ] || continue
  # XML comments are dropped first, so a commented-out package is not read as a dependency.
  body="$(perl -0pe 's/<!--.*?-->//gs' "$config")"
  ids="$(printf '%s\n' "$body" | sed -n 's/.*<package[[:space:]][^>]*id="\([^"]*\)".*/\1/p')"
  if [ -z "$ids" ]; then
    # No package at all is a valid file; packages whose ids the pattern cannot read would
    # otherwise pass with nothing checked.
    if printf '%s\n' "$body" | grep -q '<package[[:space:]]'; then
      printf 'FAIL %s lists packages whose id this check cannot read\n' "$config"
      fail=1
    fi
    continue
  fi
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    case " $table_ids " in
      *" $id "*) ;;
      *)
        printf 'FAIL %s lists package %s, which has no licence row\n' "$config" "$id"
        fail=1
        ;;
    esac
  done <<< "$ids"
done <<< "$configs"

[ "$fail" = 0 ] && echo "ok   every input is on the allow-list"
exit "$fail"
