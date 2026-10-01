CXX ?= g++
CXXFLAGS ?= -O2 -std=c++17 -Wall -Wextra
PREFIX ?= $(HOME)/.local

all: vaultos-hud

vaultos-hud: main.cpp
	$(CXX) $(CXXFLAGS) $< -o $@

install: vaultos-hud
	install -Dm755 vaultos-hud $(PREFIX)/bin/vaultos-hud

clean:
	rm -f vaultos-hud
.PHONY: all install clean
