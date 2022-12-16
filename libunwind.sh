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
        dpkg -s devscripts >/dev/null 2>&1 || sudo apt-get install devscripts
        rm -rf libunwind-1.6.2/
        apt-get source libunwind
        cd libunwind-1.6.2/
        EMAIL=thomas@glanzmann.de dch 'Dynamic page size patch applied'
        curl -sL https://tg.st/u/0001-libunwind-1.6.2-dynamic-page-size.patch > debian/patches/0001-libunwind-1.6.2-dynamic-page-size.patch
        echo '0001-libunwind-1.6.2-dynamic-page-size.patch' >> debian/patches/series
        sudo apt-get build-dep .
        dpkg-buildpackage -uc -us -a arm64
}

main "$@"
