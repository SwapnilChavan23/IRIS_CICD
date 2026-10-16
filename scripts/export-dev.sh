#!/usr/bin/env bash
# Export code from the DEV IRIS instance into DEV_Git/src. Review with `git diff` before committing.
source "$(dirname "$0")/_common.sh"
require_branch DEV
use_instance DEV
sync export
echo
git -C "$WORKTREE" status --short -- src
