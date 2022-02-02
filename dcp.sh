#!/bin/bash

set -x
set -e

unset LC_CTYPE
unset LANG

build_linux()
{
(
        test -d linux || git clone https://github.com/jannau/linux -b asahi-dcp
        cd linux
        git fetch
        git reset --hard asahi-dcp; git clean -f -x -d
        curl -s https://tg.st/u/5nly | git am -
        curl -s https://tg.st/u/0wM8 | git am -
        curl -s https://tg.st/u/m1-dcp-2022-01-30-config > .config
        make olddefconfig
        make -j 16 bindeb-pkg
)
}

mkdir -p build/dcp
cd build/dcp

build_linux
