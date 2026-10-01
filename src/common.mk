# Shared build rules for native Vault.OS helpers (plain GNU Make, no CMake).
#
# A tool Makefile sets BIN (and optionally SRCS, PKGS, LDLIBS), then:
#     include ../common.mk
#
# Targets: all, install, check-deps, clean.
#   make check-deps   exits 1 (and says why) when g++ or a pkg-config module
#                     is missing, so src/Makefile skips just that tool.
#   make install PREFIX=... DESTDIR=...   staged installs for packaging/tests.
CXX ?= g++
CXXFLAGS ?= -O2 -std=c++17 -Wall -Wextra -MMD
PKG_CONFIG ?= pkg-config
PREFIX ?= $(HOME)/.local
DESTDIR ?=
BINDIR ?= $(PREFIX)/bin

COMMON_DIR := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))
CPPFLAGS += -I$(COMMON_DIR)/libvaultos

SRCS ?= main.cpp
OBJS := $(SRCS:.cpp=.o)

ifneq ($(strip $(PKGS)),)
PKG_CFLAGS := $(shell $(PKG_CONFIG) --cflags $(PKGS) 2>/dev/null)
PKG_LIBS := $(shell $(PKG_CONFIG) --libs $(PKGS) 2>/dev/null)
endif

all: $(BIN)

$(BIN): $(OBJS)
	$(CXX) $(LDFLAGS) $(OBJS) -o $@ $(PKG_LIBS) $(LDLIBS)

%.o: %.cpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(PKG_CFLAGS) -c $< -o $@

install: $(BIN)
	install -Dm755 $(BIN) $(DESTDIR)$(BINDIR)/$(BIN)

check-deps:
	@command -v $(firstword $(CXX)) >/dev/null 2>&1 || { echo "$(BIN): $(CXX) not found"; exit 1; }
	@missing=""; for p in $(PKGS); do $(PKG_CONFIG) --exists $$p 2>/dev/null || missing="$$missing $$p"; done; \
	if [ -n "$$missing" ]; then echo "$(BIN): missing pkg-config module(s):$$missing"; exit 1; fi

clean:
	rm -f $(BIN) $(OBJS) $(OBJS:.o=.d)

.PHONY: all install check-deps clean

-include $(OBJS:.o=.d)
