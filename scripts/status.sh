#!/usr/bin/env bash
# Show differences between this worktree's src/ and its IRIS instance (DEV_Git->DEV, TEST_Git->TEST).
source "$(dirname "$0")/_common.sh"
case "$BRANCH" in
  DEV|TEST) use_instance "$BRANCH" ;;
  *) echo "ERROR: run from DEV_Git or TEST_Git (branch is '$BRANCH')." >&2; exit 1 ;;
esac
sync status
