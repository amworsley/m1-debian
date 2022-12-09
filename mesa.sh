#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

cd "$(dirname "$0")"

unset LC_CTYPE
unset LANG

main() {
        mkdir -p build
        cd build
        command -v git >/dev/null || sudo apt-get install git
        test -d mesa || git clone https://gitlab.freedesktop.org/asahi/mesa.git
        cd mesa
        git fetch -a -t
        rm -rf debian
        cp -a ../../mesa-debian debian
        EMAIL=thomas@glanzmann.de dch -v 23.0.0-`date +%Y%m%d%H%M` 'asahi wip'
        sudo apt-get build-dep .
        dpkg-buildpackage -uc -us -a arm64
}

main "$@"
