#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

usage()
{
   echo "Prepares a rust installation suitable for kernel compilation"
   echo "Usage:"
   echo " $(basename $0) [Options] [<Command> ...]"
   echo "Options:"
   echo " -h : Print usage information"
   echo " -n : Dry-run print commands instead of executing them"
   echo " -x : Enabling tracing of shell script"
   echo " -q : Disable tracing of shell script"
   echo
}

CMD="/bin/bash"
while getopts 'hnxq' argv
do
    case $argv in
    h)
       usage
       exit 0
    ;;
    n)
       echo "Dry-Run"
       DR=echo
    ;;
    q)
        echo "Disable tracing"
        set +x
	CMD="/bin/bash"
    ;;
    x)
        echo "Enabling tracing"
        set -x
	CMD="/bin/bash -x"
    ;;
    esac
done
# Obscure option syntax: A + to turn off a "no" option...
set +o nounset
if [ -n "$DR" ]; then
    DO_CMD="cat"
else
    DO_CMD="$CMD"
fi

$DR cd "$(dirname "$0")"

unset LC_CTYPE
unset LANG

$DO_CMD <<EOF
mkdir -p "$(pwd)/build"
export CARGO_HOME="$(pwd)/build/cargo"
export RUSTUP_HOME="$(pwd)/build/rust"
rm -rf ${CARGO_HOME} ${RUSTUP_HOME}
curl https://sh.rustup.rs -sSf | sh -s -- -y --no-modify-path --default-toolchain none
source "$(pwd)/build/cargo/env"
rustup override set 1.71.1
rustup default 1.71.1
rustup component add rust-src
cargo install --locked --version 0.65.1 bindgen-cli
rustup component add rustfmt
rustup component add clippy
EOF
