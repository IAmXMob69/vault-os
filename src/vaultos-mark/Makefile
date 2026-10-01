CXX ?= g++
CXXFLAGS ?= -O2 -std=c++17 -Wall -Wextra
PKGS = gtk+-3.0 cairo
PREFIX ?= $(HOME)/.local

vaultos-mark: main.cpp
	$(CXX) $(CXXFLAGS) $< -o $@ $$(pkg-config --cflags --libs $(PKGS)) -lm

install: vaultos-mark
	install -Dm755 vaultos-mark $(PREFIX)/bin/vaultos-mark

clean:
	rm -f vaultos-mark
.PHONY: install clean
