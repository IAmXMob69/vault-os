CXX ?= g++
CXXFLAGS ?= -O2 -std=c++17 -Wall -Wextra
PKGS = gtk+-3.0 gtk+-x11-3.0 cairo
PREFIX ?= $(HOME)/.local

all: vaultos-lockmark

vaultos-lockmark: main.cpp
	$(CXX) $(CXXFLAGS) $< -o $@ $$(pkg-config --cflags --libs $(PKGS)) -lm

install: vaultos-lockmark
	install -Dm755 vaultos-lockmark $(PREFIX)/bin/vaultos-lockmark

clean:
	rm -f vaultos-lockmark
.PHONY: all install clean
