#!/usr/bin/env bash
# Deploy TEST_Git/src into the TEST IRIS instance (uploads changed docs and compiles them).
#   ./scripts/deploy-test.sh --dry-run   show what would be deployed, change nothing
source "$(dirname "$0")/_common.sh"
require_branch TEST
use_instance TEST
if [[ -n "$(git -C "$WORKTREE" status --porcelain -- src)" ]]; then
  echo "ERROR: TEST_Git/src has uncommitted changes - commit or discard them first." >&2
  exit 1
fi
echo "Deploying commit $(git -C "$WORKTREE" log -1 --format='%h %s')"
sync import "$@"
