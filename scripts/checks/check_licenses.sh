#!/usr/bin/env bash
# List the third-party inputs and fail when one is outside the licence allow-list.
#
#   ./scripts/checks/check_licenses.sh
#
# The project has no package manager that an audit job can query: the tests restore one NuGet
# package through packages.config, and the Python binding downloads a pinned pybind11 archive with
# a batch script. The inventory below is maintained by hand, so a new input has to be added here as
# well as to DownloadPybind11.bat or a packages.config.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit

ALLOWED="MIT BSD-2-Clause BSD-3-Clause Apache-2.0 ISC Zlib Unlicense CC0-1.0 0BSD Python-2.0 BlueOak-1.0.0"

printf '%-66s %-9s %s\n' PACKAGE VERSION LICENSE
fail=0
while IFS='|' read -r name version license source; do
  [ -n "$name" ] || continue
  printf '%-66s %-9s %s\n' "$name" "$version" "$license"
  case " $ALLOWED " in
    *" $license "*) ;;
    *)
      printf 'FAIL %s %s is licensed %s, which the allow-list does not include\n' "$name" "$version" "$license"
      fail=1
      ;;
  esac
  echo "     from $source"
done <<'EOF'
Microsoft.googletest.v140.windesktop.msvcstl.static.rt-dyn|1.8.1.7|MIT|tests/core_tests/packages.config, tests/dll_tests/packages.config
pybind11|2.13.6|BSD-3-Clause|examples/python_binding/DownloadPybind11.bat
EOF

[ "$fail" = 0 ] && echo "ok   every input is on the allow-list"
exit "$fail"
