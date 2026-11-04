#!/usr/bin/env bash
# Local checks of the spin: run them before every push (there is no hosted CI).
#   tools/check.sh [--base DIR] [--quick]
# ShellCheck of spin.conf, the tools and the recipes, then tools/lint.sh --fetch --base DIR: the names
# the spin uses must be recipes of the spin or of the base, every source is downloaded and its sha256
# verified. DIR is packages/ of CleanLinux-Recipes: ../CleanLinux-Recipes/packages when it exists, else
# a shallow clone in .base/. --quick: no downloads (tools/hooks/pre-push).
set -euo pipefail
cd "$(dirname "$0")/.."
BASE='' QUICK=0
while (($#)); do
	case $1 in
		--base) BASE=$2 && shift 2 ;;
		--quick) QUICK=1 && shift ;;
		-h | --help) sed -n '2,7p' "$0" | cut -c3- && exit 0 ;;
		*) echo "tools/check.sh: unknown argument: $1" >&2 && exit 2 ;;
	esac
done
step() { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }

if [[ -z $BASE ]]; then
	if [[ -d ../CleanLinux-Recipes/packages ]]; then
		BASE=../CleanLinux-Recipes/packages
	else
		if [[ ! -d .base ]]; then git clone -q --depth 1 https://github.com/vovawees/CleanLinux-Recipes.git .base; fi
		BASE=.base/packages
	fi
fi
step shellcheck
shellcheck -x tools/*.sh tools/hooks/pre-push
shellcheck -s bash spin.conf packages/*/recipe
if ((QUICK)); then
	step "lint against the base ($BASE)"
	tools/lint.sh --base "$BASE"
else
	step "lint against the base ($BASE), download the sources and verify their sha256"
	tools/lint.sh --fetch --base "$BASE"
fi
