# vaultos-firstuser — first-boot wizard, C++ port of
# overlay/libexec/vaultos-firstuser.sh (which stays the fallback).
# It runs as root on a fresh install, so it is not put on a user PATH:
#   make install PREFIX=/usr DESTDIR=$airootfs  ->  /usr/lib/vaultos/libexec/vaultos-firstuser
# (default PREFIX=~/.local lands in ~/.local/lib/vaultos/libexec, off PATH).
BIN = vaultos-firstuser
PKGS = libxcrypt
BINDIR ?= $(PREFIX)/lib/vaultos/libexec
include ../common.mk
