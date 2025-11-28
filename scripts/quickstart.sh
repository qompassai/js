#!/usr/bin/env bash
# /qompassai/JS/scripts/quickstart.sh
# Qompass AI JS Quickstart
# Copyright (C) 2025 Qompass AI, All rights reserved
# --------------------------------------------------
set -euo pipefail

platform=$(uname -ms)

if [[ ${OS:-} = Windows_NT ]]; then
    if [[ $platform != MINGW64* ]]; then
        powershell -c "irm bun.com/install.ps1|iex"
        exit $?
    fi
fi

if [[ -t 1 ]]; then
    Color_Off='\033[0m'
    Red='\033[0;31m'
    Green='\033[0;32m'
    Dim='\033[0;2m'
    Bold_Green='\033[1;32m'
    Bold_White='\033[1m'
else
    Color_Off=''
    Red=''
    Green=''
    Dim=''
    Bold_Green=''
    Bold_White=''
fi

error() {
    echo -e "${Red}error${Color_Off}:" "$@" >&2
    exit 1
}
info() { echo -e "${Dim}$@ ${Color_Off}"; }
info_bold() { echo -e "${Bold_White}$@ ${Color_Off}"; }
success() { echo -e "${Green}$@ ${Color_Off}"; }

command -v unzip >/dev/null || error 'unzip is required to install bun'
command -v curl >/dev/null || error 'curl is required to install bun'

if [[ $# -gt 2 ]]; then
    error 'Too many arguments, only 2 are allowed. The first can be a specific tag of bun to install. (e.g. "bun-v0.1.4") The second can be a build variant of bun to install. (e.g. "debug-info")'
fi

case $platform in
'Darwin x86_64')
    target=darwin-x64
    ;;
'Darwin arm64')
    target=darwin-aarch64
    ;;
'Linux aarch64' | 'Linux arm64')
    target=linux-aarch64
    ;;
'MINGW64'*)
    target=windows-x64
    ;;
'Linux x86_64' | *)
    target=linux-x64
    ;;
esac

case "$target" in
'linux'*)
    if [ -f /etc/alpine-release ]; then
        target="$target-musl"
    fi
    ;;
esac

if [[ $target = darwin-x64 ]]; then
    # Is this process running in Rosetta?
    if [[ $(sysctl -n sysctl.proc_translated 2>/dev/null) = 1 ]]; then
        target=darwin-aarch64
        info "Your shell is running in Rosetta 2. Downloading bun for $target instead"
    fi
fi

GITHUB=${GITHUB-"https://github.com"}
github_repo="$GITHUB/oven-sh/bun"

# If AVX2 isn't supported, use the -baseline build
case "$target" in
'darwin-x64'*)
    if [[ $(sysctl -a | grep machdep.cpu | grep AVX2) == '' ]]; then
        target="$target-baseline"
    fi
    ;;
'linux-x64'*)
    if [[ $(cat /proc/cpuinfo | grep avx2) = '' ]]; then
        target="$target-baseline"
    fi
    ;;
esac

exe_name=bun

if [[ $# = 2 && $2 = debug-info ]]; then
    target=$target-profile
    exe_name=bun-profile
    info "You requested a debug build of bun. More information will be shown if a crash occurs."
fi

if [[ $# = 0 ]]; then
    bun_uri=$github_repo/releases/latest/download/bun-$target.zip
else
    bun_uri=$github_repo/releases/download/$1/bun-$target.zip
fi

bin_dir="$HOME/.local/bin"
exe="$bin_dir/bun"

mkdir -p "$bin_dir" || error "Failed to create bin directory \"$bin_dir\""

curl --fail --location --progress-bar --output "$exe.zip" "$bun_uri" ||
    error "Failed to download bun from \"$bun_uri\""

unzip -oqd "$bin_dir" "$exe.zip" ||
    error 'Failed to extract bun'

mv "$bin_dir/bun-$target/$exe_name" "$exe" ||
    error 'Failed to move extracted bun to destination'

chmod +x "$exe" ||
    error 'Failed to set permissions on bun executable'

rm -r "$bin_dir/bun-$target" "$exe.zip"

tildify() {
    if [[ $1 = $HOME/* ]]; then
        local replacement=\~/
        echo "${1/$HOME\//$replacement}"
    else
        echo "$1"
    fi
}

success "bun was installed successfully to $Bold_Green$(tildify "$exe")"

if command -v bun >/dev/null; then
    IS_BUN_AUTO_UPDATE=true $exe completions &>/dev/null || :
    echo "Run 'bun --help' to get started"
    exit
fi

tilde_bin_dir=$(tildify "$bin_dir")
echo
info "To use bun, add $tilde_bin_dir to your \$PATH. For example:"
echo
info_bold "  export PATH=\"$tilde_bin_dir:\$PATH\""
echo
info_bold "  bun --help"

exit 0
