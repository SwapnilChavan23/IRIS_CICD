#!/usr/bin/env bash
# Load DEV_Git/src into the DEV IRIS instance (e.g. after a rename or pulling changes from git).
#   ./scripts/load-dev.sh --dry-run   show what would be loaded, change nothing
source "$(dirname "$0")/_common.sh"
require_branch DEV
use_instance DEV
sync import "$@"
