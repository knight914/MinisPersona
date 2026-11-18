#!/usr/bin/env bash
set -euo pipefail

scheme=${1:?missing scheme}
mode=${2:?missing mode}
version=${3:-}
case "$scheme" in
  rootless)
    repository=theos/theos
    revision=8167f59de02fd32cf45b16bfcb1330dfa5c9974c
    architecture=iphoneos-arm64
    prefix=./var/jb
    ;;
  roothide)
    repository=roothide/theos
    revision=958fea4f779943505b15b93c88bb4db8d97b346d
    architecture=iphoneos-arm64e
    prefix=.
    ;;
  *) echo 'Unknown Theos scheme' >&2; exit 1 ;;
esac
case "$mode" in
  compile) formulas=(make ldid) ;;
  package)
    [[ "$version" =~ ^0\.0\.[1-9][0-9]*$ ]]
    python3 -c 'import re, sys; from pathlib import Path; sys.exit(re.findall(r"^Version: (\S+)$", Path("control").read_text(), re.M) != [sys.argv[1]])' "$version"
    formulas=(make ldid dpkg)
    ;;
  *) echo 'Unknown build mode' >&2; exit 1 ;;
esac

export THEOS="${RUNNER_TEMP:?}/theos-$scheme-$mode"
export THEOS_PACKAGE_SCHEME="$scheme"
git clone --no-checkout "https://github.com/$repository.git" "$THEOS"
git -C "$THEOS" checkout --detach "$revision"
git -C "$THEOS" submodule update --init --recursive
git -C "$THEOS" rev-parse HEAD
git -C "$THEOS" submodule status --recursive
brew install "${formulas[@]}"
brew list --versions "${formulas[@]}"
export PATH="$(brew --prefix make)/libexec/gnubin:$PATH"
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-path
xcrun --sdk iphoneos --show-sdk-version
make --version

if [[ "$mode" = compile ]]; then
  make all FINALPACKAGE=1
  if compgen -G 'packages/*.deb' >/dev/null; then
    echo 'Unexpected Debian package in compile-only job' >&2
    exit 1
  fi
  exit 0
fi

make clean package FINALPACKAGE=1
set -- packages/*.deb
test "$#" = 1
test -f "$1"
test "$(dpkg-deb -f "$1" Package)" = com.knight914.minispersona
test "$(dpkg-deb -f "$1" Version)" = "$version"
test "$(dpkg-deb -f "$1" Architecture)" = "$architecture"
depends=$(dpkg-deb -f "$1" Depends)
[[ "$depends" == *mobilesubstrate* && "$depends" == *'firmware (>= 15.0)'* ]]
dpkg-deb -I "$1"
dpkg-deb -c "$1"
extract=$(mktemp -d)
trap 'rm -rf "$extract"' EXIT
dpkg-deb -x "$1" "$extract"
location="$extract/$prefix/Library/MobileSubstrate/DynamicLibraries"
xcrun lipo -verify_arch arm64 arm64e "$location/MinisPersona.dylib"
python3 - "$location/MinisPersona.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as file:
    assert plistlib.load(file) == {'Filter': {'Bundles': ['com.openminis.app']}}
PY
