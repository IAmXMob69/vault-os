CXX ?= g++
CXXFLAGS ?= -O2 -std=c++17 -Wall -Wextra
PREFIX ?= $(HOME)/.local

all: vaultos-firstuser

vaultos-firstuser: main.cpp
	$(CXX) $(CXXFLAGS) $< -o $@

# Not installed to ~/.local: this runs as root on a fresh install. The ISO
# build copies it to /usr/lib/vaultos/libexec/.
install: vaultos-firstuser

clean:
	rm -f vaultos-firstuser
.PHONY: all install clean
