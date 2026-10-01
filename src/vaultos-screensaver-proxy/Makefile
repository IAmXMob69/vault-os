CXX ?= g++
CXXFLAGS ?= -O2 -std=c++17 -Wall -Wextra
PKGS = gio-2.0 gio-unix-2.0 x11
PREFIX ?= $(HOME)/.local

all: vaultos-screensaver-proxy

vaultos-screensaver-proxy: main.cpp
	$(CXX) $(CXXFLAGS) $< -o $@ $$(pkg-config --cflags --libs $(PKGS))

install: vaultos-screensaver-proxy
	install -Dm755 vaultos-screensaver-proxy $(PREFIX)/bin/vaultos-screensaver-proxy

clean:
	rm -f vaultos-screensaver-proxy
.PHONY: all install clean
