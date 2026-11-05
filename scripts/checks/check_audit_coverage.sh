#!/usr/bin/env bash
# Fail when a manifest is present that no audit job claims.
#
#   ./scripts/checks/check_audit_coverage.sh
#
# A security job that reports green over something it never looked at is worse than no job, because
# it reads as evidence.
#
# Markers name repository-relative paths, not file names: a marker for a root file never covers a
# same-named file in a subdirectory. A manifest that is deliberately not audited is named on a
# `# not audited: <path> <reason>` marker so the exemption stays visible.
#
# The list below is EVERY manifest this guard knows, not the ones this repository lacks. What is
# already covered is subtracted from the `# audits:` markers in security.yml, so deleting an audit
# job makes its manifests start failing here rather than quietly going unscanned, and a manifest
# that is removed and later comes back is still caught.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit

KNOWN="package.json requirements.txt pyproject.toml Cargo.toml go.mod pubspec.yaml Gemfile composer.json packages.config"
audited=$(grep -o '# audits:.*' .github/workflows/security.yml | sed 's/# audits://')
echo "claimed by an audit job:$audited"

# A `# not audited: <path> <reason>` marker exempts one manifest that no job audits on purpose.
not_audited=$(grep -o '# not audited:[[:space:]]*[^[:space:]]*' .github/workflows/security.yml \
  | sed -E 's/# not audited:[[:space:]]*//')
named=" $(printf '%s %s' "$audited" "$not_audited" | tr '\n' ' ') "

missing=""
for m in $KNOWN; do
  while IFS= read -r path; do
    case "$named" in *" $path "*) continue ;; esac
    missing="$missing$path"$'\n'
  done < <(git ls-files -co --exclude-standard -- "$m" "*/$m")
done

if [ -n "$missing" ]; then
  echo "An ecosystem with no audit job:"
  printf '%s' "$missing"
  echo
  echo "FAIL: add its vulnerability, outdated and licence jobs to this workflow, declare"
  echo "      its manifests in that job's '# audits:' marker, and add the ecosystem to"
  echo "      .github/dependabot.yml, before merging."
  exit 1
fi
echo "ok   every manifest present is claimed by an audit job"
