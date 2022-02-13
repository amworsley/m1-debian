#!/bin/sh

chroot /target debconf-set-selections < /options
