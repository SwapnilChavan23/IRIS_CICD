#!/usr/bin/env bash
# Shared helpers for the deployment scripts. Sourced, not executed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKTREE="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
BRANCH="$(git -C "$WORKTREE" rev-parse --abbrev-ref HEAD)"
# .env lives in the main checkout (/Users/home/IRIS_CICD/.env), shared by both worktrees
MAIN_ROOT="$(cd "$(git -C "$WORKTREE" rev-parse --git-common-dir)/.." && pwd)"

if [[ -f "$MAIN_ROOT/.env" ]]; then
  set -a; source "$MAIN_ROOT/.env"; set +a
fi

require_branch() {
  if [[ "$BRANCH" != "$1" ]]; then
    echo "ERROR: run this from the $1 worktree (current folder is on branch '$BRANCH')." >&2
    exit 1
  fi
}

# use_instance DEV|TEST -> maps IRIS_DEV_* / IRIS_TEST_* onto the IRIS_* vars iris_sync.py reads
use_instance() {
  local p="IRIS_$1_"
  local v
  for v in HOST PORT NS USER PASS; do
    local src="${p}${v}"
    [[ -n "${!src:-}" ]] && export "IRIS_${v}=${!src}"
  done
  return 0
}

sync() { python3 "$SCRIPT_DIR/iris_sync.py" --workdir "$WORKTREE" "$@"; }
