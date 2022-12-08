#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

cd "$(dirname "$0")"

unset LC_CTYPE
unset LANG

main() {
        sudo apt-get build-dep mesa
        cd build
        test -d mesa || git clone https://gitlab.freedesktop.org/asahi/mesa.git
        cd mesa
        git fetch -a -t
        rm -rf debian
        cp -a ../../mesa-debian debian
        dpkg-buildpackage -uc -us -a arm64
}

main "$@"
