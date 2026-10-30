#!/usr/bin/env bash
# Point git at the repo-versioned hooks. Run once per clone:
#   scripts/git-hooks/install.sh
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
chmod +x "$repo_root/scripts/git-hooks/pre-commit" "$repo_root/scripts/check-deps.sh"
git -C "$repo_root" config core.hooksPath scripts/git-hooks
echo "Installed: core.hooksPath -> scripts/git-hooks"
