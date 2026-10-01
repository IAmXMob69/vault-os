CXX ?= g++
CXXFLAGS ?= -O2 -std=c++17 -Wall -Wextra
PREFIX ?= $(HOME)/.local

all: vaultos

vaultos: main.cpp
	$(CXX) $(CXXFLAGS) -DVAULTOS_SRC_ROOT='"$(abspath ../..)"' $< -o $@

install: vaultos
	install -Dm755 vaultos $(PREFIX)/bin/vaultos

clean:
	rm -f vaultos
.PHONY: all install clean
