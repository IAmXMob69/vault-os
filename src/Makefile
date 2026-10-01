# Native Vault.OS helpers. `make -C src install` puts them in $(PREFIX)/bin
# (default ~/.local/bin). Each tool is built on its own: when its g++ or
# pkg-config deps are missing it is skipped and its Python/bash fallback stays
# in charge. A real compile error is reported and the loop carries on; the
# exit status is non-zero if any tool failed to build.
SUBDIRS = vaultos vaultos-mark vaultos-screensaver-proxy vaultos-lockmark vaultos-hud vaultos-firstuser \
          vaultos-xq vaultos-close-all vaultos-chromium-theme
PREFIX ?= $(HOME)/.local

# pkg-config deps for tool Makefiles that predate common.mk (no check-deps target).
LEGACY = vaultos vaultos-hud vaultos-firstuser vaultos-mark vaultos-screensaver-proxy vaultos-lockmark
DEPS_vaultos =
DEPS_vaultos-hud =
DEPS_vaultos-firstuser =
DEPS_vaultos-mark = gtk+-3.0 cairo
DEPS_vaultos-screensaver-proxy = gio-2.0 gio-unix-2.0 x11
DEPS_vaultos-lockmark = gtk+-3.0 gtk+-x11-3.0 cairo
rparen := )
LEGACY_CASE = $(foreach t,$(LEGACY),$(t)$(rparen) echo "$(DEPS_$(t))";;)

# Prints nothing and succeeds when tool $$d can be built, else the reason.
CHECK = if grep -q '^include .*common\.mk' $$d/Makefile; then \
	    $(MAKE) -s --no-print-directory -C $$d check-deps 2>&1; \
	  else \
	    command -v $${CXX:-g++} >/dev/null 2>&1 || { echo "g++ not found"; exit 1; }; \
	    miss=""; for p in $$(case $$d in $(LEGACY_CASE) esac); do \
	      pkg-config --exists $$p 2>/dev/null || miss="$$miss $$p"; done; \
	    [ -z "$$miss" ] || { echo "missing pkg-config module(s):$$miss"; exit 1; }; \
	  fi

all install:
	@fail=0; for d in $(SUBDIRS); do \
	  [ -f $$d/Makefile ] || continue; \
	  why=$$($(CHECK)) || { echo "skip $$d: $$why"; continue; }; \
	  $(MAKE) -C $$d $@ PREFIX=$(PREFIX) || { echo "FAILED $$d (fallback stays)"; fail=1; }; \
	done; exit $$fail

clean:
	@for d in $(SUBDIRS); do [ -f $$d/Makefile ] && $(MAKE) -C $$d clean; done; true

check-deps:
	@for d in $(SUBDIRS); do \
	  [ -f $$d/Makefile ] || continue; \
	  if why=$$($(CHECK)); then echo "ok    $$d"; else echo "skip  $$d: $$why"; fi; \
	done

.PHONY: all install clean check-deps
