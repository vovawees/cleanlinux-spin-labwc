#!/usr/bin/env bash
# Self-contained checker of a spin repository (no burn needed), used by tools/check.sh.
#   tools/lint.sh [--fetch] [--base DIR]
# Checks spin.conf and the recipes in packages/ (category=extra). --fetch also downloads the remote
# sources and verifies their sha256. --base DIR: packages/ of CleanLinux-Recipes; then every package of
# SPIN_PACKAGES, every dependency and every name in package.features must be a recipe of the spin or of
# the base (without it only the spin's own names are checked).
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")/.."
GNU_MIRROR=${GNU_MIRROR:-https://ftpmirror.gnu.org/gnu}
KERNEL_MIRROR=${KERNEL_MIRROR:-https://cdn.kernel.org/pub/linux}
BUILD_TYPES=(autotools meson cmake make cargo python custom meta)
OPTIONS=('!lto' '!strip' '!hardening' '!prune' '!linker' staticlibs emptydirs o3)
NAME_RE='^[a-z0-9][a-z0-9+._-]*$'
FETCH=0 BASE=''
while (($#)); do
	case $1 in
		--fetch) FETCH=1 && shift ;;
		--base) BASE=${2:?} && shift 2 ;;
		*) echo "usage: tools/lint.sh [--fetch] [--base DIR]" >&2 && exit 2 ;;
	esac
done
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
problems=0
bad() {
	echo "$*"
	problems=$((problems + 1))
}
in_list() {
	local n=$1 x
	shift
	for x; do [[ $x == "$n" ]] && return 0; done
	return 1
}
url_expand() {
	case $1 in
		gnu://*) printf '%s\n' "$GNU_MIRROR/${1#gnu://}" ;;
		kernel://*) printf '%s\n' "$KERNEL_MIRROR/${1#kernel://}" ;;
		*) printf '%s\n' "$1" ;;
	esac
}
# the split packages of the recipes in DIR: "split recipe" lines
splits_of() {
	local r s
	for r in "$1"/*/recipe; do
		while IFS= read -r s; do
			[[ -n $s ]] && printf '%s %s\n' "$s" "$(basename "$(dirname "$r")")"
		done < <(split=() CARCH=x86_64 CHOST=x86_64-cleanlinux-linux-gnu bash -c '. "$1" >/dev/null 2>&1; printf "%s\n" "${split[@]}"' _ "$r")
	done
}
declare -A KNOWN=() # every package name a spin may use: its recipes and splits, those of the base
for r in packages/*/recipe; do r=${r%/recipe} && KNOWN[${r#packages/}]=spin; done
while read -r s _; do KNOWN[$s]=spin; done < <(splits_of packages)
if [[ -n $BASE ]]; then
	[[ -d $BASE ]] || { echo "lint: --base $BASE is not a directory" >&2 && exit 2; }
	for r in "$BASE"/*/recipe; do
		r=${r%/recipe} r=${r##*/}
		[[ -z ${KNOWN[$r]:-} ]] || bad "packages/$r: the base has a recipe of the same name (a spin adds, it does not replace)"
		KNOWN[$r]=base
	done
	while read -r s _; do KNOWN[$s]=${KNOWN[$s]:-base}; done < <(splits_of "$BASE")
fi

# spin.conf: static shell (burn parses it, it does not run it)
if [[ ! -f spin.conf ]]; then
	bad "spin.conf is missing"
elif ! bash -n spin.conf; then
	bad "spin.conf: syntax error"
else
	SPIN_NAME='' SPIN_DESC='' SPIN_BASE='' SPIN_FEATURES=''
	SPIN_PACKAGES=() SPIN_SERVICES=() SPIN_USER_SERVICES=()
	# shellcheck source=/dev/null
	. ./spin.conf
	[[ -z $SPIN_NAME || $SPIN_NAME =~ $NAME_RE ]] || bad "spin.conf: bad SPIN_NAME '$SPIN_NAME'"
	[[ -n $SPIN_DESC ]] || bad "spin.conf: SPIN_DESC is empty"
	[[ $SPIN_BASE =~ ^[1-9][0-9]*$ ]] || bad "spin.conf: SPIN_BASE must be the contract level of the base (1, 2, ...)"
	((${#SPIN_PACKAGES[@]})) || bad "spin.conf: SPIN_PACKAGES is empty"
	for p in "${SPIN_PACKAGES[@]}"; do
		[[ $p =~ $NAME_RE ]] || bad "spin.conf: bad package name '$p'"
		if [[ -n $BASE ]]; then
			[[ -n ${KNOWN[$p]:-} ]] || bad "spin.conf: package '$p' is neither a recipe of the spin nor of the base"
		fi
	done
	for f in $SPIN_FEATURES; do
		[[ ${f#[+-]} =~ ^[a-z0-9][a-z0-9_-]*$ ]] || bad "spin.conf: bad feature '$f'"
	done
	for s in "${SPIN_SERVICES[@]}" "${SPIN_USER_SERVICES[@]}"; do
		[[ $s =~ ^[A-Za-z0-9][A-Za-z0-9@._-]*$ ]] || bad "spin.conf: bad service name '$s'"
	done
fi

# package.features: "PACKAGE FEATURE..." lines, as /etc/burn/package.features
if [[ -f package.features ]]; then
	n=0
	while IFS= read -r line || [[ -n $line ]]; do
		n=$((n + 1))
		line=${line%%#*}
		read -ra w <<<"$line"
		((${#w[@]})) || continue
		((${#w[@]} > 1)) || bad "package.features:$n: '${w[0]}' without features"
		[[ ${w[0]} =~ $NAME_RE ]] || bad "package.features:$n: bad package name '${w[0]}'"
		[[ -z $BASE || -n ${KNOWN[${w[0]}]:-} ]] || bad "package.features:$n: unknown package '${w[0]}'"
		for f in "${w[@]:1}"; do
			[[ ${f#[+-]} =~ ^[a-z0-9][a-z0-9_-]*$ ]] || bad "package.features:$n: bad feature '$f'"
		done
	done <package.features
fi

# check_one PKG: prints problems, one per line
check_one() (
	local dir=packages/$1 s f p i url file sum
	bash -n "$dir/recipe" || {
		echo "$1: syntax error"
		exit 0
	}
	name='' version='' release=1 summary='' homepage='' category='' build_type=autotools
	license=() source=() sha256=() depends=() makedepends=() features=() patches=() options=() split=()
	CARCH=x86_64 CHOST=x86_64-cleanlinux-linux-gnu
	# shellcheck source=/dev/null
	. "$dir/recipe"
	[[ $name == "$1" ]] || echo "$1: name '$name' does not match the directory"
	[[ $version =~ ^[A-Za-z0-9._+~]+$ ]] || echo "$1: bad version '$version'"
	[[ $release =~ ^[1-9][0-9]*$ ]] || echo "$1: release must be a positive integer"
	[[ -n $summary ]] || echo "$1: summary is empty"
	((${#license[@]})) || echo "$1: license is empty"
	[[ $homepage == http*://* ]] || echo "$1: homepage must be a URL"
	[[ $category == extra ]] || echo "$1: the recipes of a spin are category=extra (got '$category')"
	in_list "$build_type" "${BUILD_TYPES[@]}" || echo "$1: unknown build_type '$build_type'"
	if [[ $build_type != meta ]] && ((${#source[@]} == 0)); then echo "$1: no sources"; fi
	((${#source[@]} == ${#sha256[@]})) || echo "$1: ${#source[@]} sources but ${#sha256[@]} sha256 sums"
	local -a names=() feats=()
	for i in "${!source[@]}"; do
		s=${source[$i]} sum=${sha256[$i]:-}
		if [[ $s == *::* ]]; then file=${s%%::*} s=${s#*::}; else file=${s##*/}; fi
		names+=("$file")
		[[ $sum =~ ^[0-9a-f]{64}$ || $sum == SKIP ]] || echo "$1: bad sha256 for $file"
		if [[ $s != *://* ]]; then
			[[ -f $dir/$s ]] || echo "$1: local source '$s' is missing"
			[[ $sum == SKIP || ! -f $dir/$s || $(sha256sum "$dir/$s" | cut -d' ' -f1) == "$sum" ]] ||
				echo "$1: sha256 mismatch for local file $s"
			continue
		fi
		case $s in https://* | gnu://* | kernel://*) ;; *) echo "$1: insecure URL $s (use https)" ;; esac
		[[ $sum != SKIP ]] || echo "$1: remote source $file needs a real sha256"
		if ((FETCH)) && [[ $sum != SKIP ]]; then
			url=$(url_expand "$s")
			if ! curl -fsSL --retry 3 --connect-timeout 20 -o "$tmp/$file" "$url"; then
				echo "$1: download failed: $url"
				continue
			fi
			[[ $(sha256sum "$tmp/$file" | cut -d' ' -f1) == "$sum" ]] || echo "$1: sha256 mismatch for $url"
			rm -f "$tmp/$file"
		fi
	done
	for p in "${patches[@]}"; do
		[[ -f $dir/$p || -f $dir/patches/$p ]] || in_list "$p" "${names[@]}" || echo "$1: patch '$p' is missing"
	done
	for f in "${features[@]}"; do
		[[ $f =~ ^[+-]?[a-z0-9][a-z0-9_-]*$ ]] || echo "$1: bad feature '$f'"
		feats+=("${f#[+-]}")
	done
	local -a deps=("${depends[@]}" "${makedepends[@]}")
	local key n
	for s in "${split[@]}"; do
		[[ $s =~ $NAME_RE ]] || echo "$1: bad split name '$s'"
		key=${s//[^A-Za-z0-9_]/_}
		local -n files_ref="files_$key" summary_ref="summary_$key" depends_ref="depends_$key"
		n=0
		if declare -p "files_$key" >/dev/null 2>&1; then n=${#files_ref[@]}; fi
		((n)) || echo "$1: split '$s' has no files_$key"
		[[ -n ${summary_ref:-} ]] || echo "$1: split '$s' has no summary_$key"
		if declare -p "depends_$key" >/dev/null 2>&1; then deps+=("${depends_ref[@]}"); fi
		unset -n files_ref summary_ref depends_ref
	done
	for p in "${deps[@]}"; do
		if [[ -n $BASE ]]; then
			[[ -n ${KNOWN[${p%%:*}]:-} ]] || echo "$1: unknown dependency '${p%%:*}' (not in the spin, not in the base)"
		fi
		if [[ $p == *:* ]]; then
			f=${p#*:}
			in_list "${f#!}" "${feats[@]}" || echo "$1: dependency '$p' uses undeclared feature '${f#!}'"
		fi
	done
	for f in "${options[@]}"; do in_list "$f" "${OPTIONS[@]}" || echo "$1: unknown option '$f'"; done
	while IFS= read -r -d '' f; do
		if (($(stat -c %s "$f") > 262144)); then
			echo "$1: file too large for a recipe repository: ${f#"$dir"/}"
		elif [[ -s $f ]] && ! grep -Iq . "$f"; then
			echo "$1: binary file not allowed: ${f#"$dir"/}"
		fi
	done < <(find "$dir" -type f -print0)
)

pkgs=()
for r in packages/*/recipe; do r=${r%/recipe} && pkgs+=("${r#packages/}"); done
for p in "${pkgs[@]}"; do
	out=$(check_one "$p" 2>&1) || out="$p: recipe failed to load"$'\n'"$out"
	if [[ -n $out ]]; then
		printf '%s\n' "$out"
		problems=$((problems + $(wc -l <<<"$out")))
	fi
done
if ((problems)); then
	echo "lint: $problems problem(s)"
	exit 1
fi
echo "lint: spin.conf and ${#pkgs[@]} recipe(s) OK$( ((FETCH)) && echo ', sources verified')$([[ -n $BASE ]] && echo ', names checked against the base')"
