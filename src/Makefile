# Native Vault.OS helpers. `make -C src install` puts them in ~/.local/bin.
SUBDIRS = vaultos vaultos-mark vaultos-screensaver-proxy vaultos-lockmark
PREFIX ?= $(HOME)/.local

all install clean:
	@for d in $(SUBDIRS); do $(MAKE) -C $$d $@ PREFIX=$(PREFIX) || exit 1; done
.PHONY: all install clean
