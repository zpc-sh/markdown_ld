#!/usr/bin/env bash
set -euo pipefail

# Fails if forbidden native build artifacts are tracked by Git.

fail=false
msg()
{
  echo "[native-guard] $*"
}

patterns=(
  '^native/.*/target/'
  '^native/target/'
  '^native/.*/true/'
  '^native/true/'
  '^priv/native/.*\.(so|dll|dylib)$'
)

tracked=$(git ls-files -z | tr '\0' '\n')
offenders=$(printf '%s\n' "$tracked" | rg -n "$(IFS='|'; echo "${patterns[*]}")" || true)

if [[ -n "$offenders" ]]; then
  msg "Forbidden tracked artifacts found:"
  echo "$offenders"
  fail=true
fi

if [[ "$fail" == true ]]; then
  msg "Refusing to proceed. See .gitignore and remove with: git rm -r --cached <paths>"
  exit 1
else
  msg "OK: no tracked native build artifacts."
fi

