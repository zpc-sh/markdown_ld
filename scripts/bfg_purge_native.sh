#!/usr/bin/env bash
set -euo pipefail

# BFG-based history cleanup for native build artifacts.
# Safe defaults: requires running inside a MIRROR (bare) clone, confirms before pushing.

usage() {
  cat <<'USAGE'
Usage: scripts/bfg_purge_native.sh [--bfg /path/to/bfg.jar] [--dry-run] [--yes]

Removes from Git history using BFG (mirror clone expected):
  - Folders: target, true (e.g., native/**/target, native/**/true)
  - Files: priv/native/*.so, *.dylib, *.dll, markdown_ld-*.tar, .DS_Store

Flags:
  --bfg PATH   Path to bfg.jar. Defaults to $BFG_JAR if set, otherwise tries 'bfg.jar' in CWD.
  --dry-run    Preview changes; do not rewrite history or push.
  --yes        Skip interactive push confirmation.

Notes:
  - Run inside a mirror (bare) clone: `git clone --mirror <remote> repo.git && cd repo.git`
  - After running without --dry-run, the script will offer to push with --force-with-lease.
USAGE
}

DRY_RUN=false
AUTO_YES=false
BFG_JAR=${BFG_JAR:-}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true; shift ;;
    --yes)
      AUTO_YES=true; shift ;;
    --bfg)
      BFG_JAR="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

# Ensure we are in a bare repo (mirror clone)
if [[ "$(git rev-parse --is-bare-repository 2>/dev/null || echo false)" != "true" ]]; then
  echo "Error: This script must be run inside a mirror (bare) clone." >&2
  echo "Example: git clone --mirror <remote> repo.git && cd repo.git" >&2
  exit 1
fi

# Resolve BFG jar
if [[ -z "${BFG_JAR}" ]]; then
  if [[ -f ./bfg.jar ]]; then
    BFG_JAR=./bfg.jar
  else
    echo "Error: Provide --bfg /path/to/bfg.jar or place bfg.jar in the current directory." >&2
    exit 1
  fi
fi
if [[ ! -f "${BFG_JAR}" ]]; then
  echo "Error: BFG jar not found at ${BFG_JAR}" >&2
  exit 1
fi

# Ensure Java is available
if ! command -v java >/dev/null 2>&1; then
  echo "Error: Java is required to run BFG (java not found in PATH)." >&2
  exit 1
fi

echo "Repo: $(pwd)"
echo "Bare: $(git rev-parse --is-bare-repository)"
echo "BFG:  ${BFG_JAR}"

BFG_FLAGS=(
  # Remove build folders
  --delete-folders target
  --delete-folders true
  # Remove compiled NIFs & tarballs & macOS noise
  --delete-files 'priv/native/*.so'
  --delete-files 'priv/native/*.dylib'
  --delete-files 'priv/native/*.dll'
  --delete-files 'markdown_ld-*.tar'
  --delete-files '.DS_Store'
)

if [[ "${DRY_RUN}" == "true" ]]; then
  echo "Running BFG dry-run (no history rewrite)..."
  java -jar "${BFG_JAR}" --dry-run "${BFG_FLAGS[@]}" . || true
  echo "Dry-run complete. No changes were written."
  exit 0
fi

echo "Running BFG rewrite..."
java -jar "${BFG_JAR}" "${BFG_FLAGS[@]}" .

echo "Cleaning and repacking..."
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Confirm before pushing
if [[ "${AUTO_YES}" != "true" ]]; then
  read -r -p "Push rewritten history to remotes with --force-with-lease? [y/N] " resp
  case "$resp" in
    y|Y|yes|YES) ;;
    *) echo "Skipping push. You can push later with:\n  git push --force-with-lease --all\n  git push --force-with-lease --tags"; exit 0 ;;
  esac
fi

echo "Pushing with --force-with-lease..."
git push --force-with-lease --all
git push --force-with-lease --tags
echo "Done. Ensure collaborators rebase or recreate branches onto the new main." 

