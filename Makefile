DESTDIR ?= 
prefix ?= /usr/local
exec_prefix ?= $(prefix)

bindir ?= $(exec_prefix)/bin
libdir ?= $(exec_prefix)/lib
libexecdir ?= $(exec_prefix)/libexec

datarootdir ?= $(prefix)/share
datadir ?= $(datarootdir)

sysconfdir ?= /etc/local

VPNSLICE_HELPERS_DIR ?= $(libexecdir)/vpnslice
VPNSLICE_CONFIG_DIR ?= $(sysconfdir)/vpnslice
VPNSLICE_STATE_DIR ?= /tmp/vpnslice
SYSTEMD_DIR ?= $(libdir)/systemd
POLKIT_DIR ?= $(datadir)/polkit-1

.PHONY: dirs all clean install build

all: builddirs
	cp Makefile --target-directory=build/
	make -C build/ build

builddirs:
	mkdir --parents build
	mkdir --parents build/bin
	mkdir --parents build/examples
	mkdir --parents build/helpers
	mkdir --parents build/polkit
	mkdir --parents build/systemd
	mkdir --parents build/systemd/system
	mkdir --parents build/systemd/user

clean:
	find build/ -mindepth 1 -not -name '.gitignore' -delete

install:
	test -f build/bin/vpnslice-launch
	mkdir --parents $(DESTDIR)$(bindir)
	mkdir --parents $(DESTDIR)$(libexecdir)/vpnslice
	mkdir --parents $(DESTDIR)$(SYSTEMD_DIR)/system
	mkdir --parents $(DESTDIR)$(SYSTEMD_DIR)/user
	mkdir --parents $(DESTDIR)$(POLKIT_DIR)/rules.d
	mkdir --parents $(DESTDIR)$(VPNSLICE_CONFIG_DIR)
	install --mode=755 ./build/bin/* --target-directory=$(DESTDIR)$(bindir)
	install --mode=755 ./build/helpers/* --target-directory=$(DESTDIR)$(libexecdir)/vpnslice
	install --mode=644 ./build/polkit/* --target-directory=$(DESTDIR)$(POLKIT_DIR)/rules.d
	install --mode=644 ./build/systemd/system/* --target-directory=$(DESTDIR)$(SYSTEMD_DIR)/system
	install --mode=644 ./build/systemd/user/* --target-directory=$(DESTDIR)$(SYSTEMD_DIR)/user
	install --mode=640 ./build/examples/* --target-directory=$(DESTDIR)$(VPNSLICE_CONFIG_DIR)

build: sedscript binaries helpers systemd polkit examples

sedscript:
	echo 's|{{ prefix }}|$(prefix)|g' > sedscript.sed
	echo 's|{{ exec_prefix }}|$(exec_prefix)|g' >> sedscript.sed
	echo 's|{{ bindir }}|$(bindir)|g' >> sedscript.sed
	echo 's|{{ libdir }}|$(libdir)|g' >> sedscript.sed
	echo 's|{{ libexecdir }}|$(libexecdir)|g' >> sedscript.sed
	echo 's|{{ VPNSLICE_HELPERS_DIR }}|$(VPNSLICE_HELPERS_DIR)|g' >> sedscript.sed
	echo 's|{{ VPNSLICE_CONFIG_DIR }}|$(VPNSLICE_CONFIG_DIR)|g' >> sedscript.sed
	echo 's|{{ VPNSLICE_STATE_DIR }}|$(VPNSLICE_STATE_DIR)|g' >> sedscript.sed
	echo 's|{{ SYSTEMD_DIR }}|$(SYSTEMD_DIR)|g' >> sedscript.sed

binaries: ./bin/vpnslice-launch ./bin/vpnslice-launch-standalone ./bin/vpnslice-setup-standalone

./bin/%: ../sources/$@ sedscript
	sed --file=./sedscript.sed ../sources/$@ > $@

helpers: ./helpers/vpnslice-setup-system ./helpers/vpnslice-user-finalize ./helpers/vpnslice-user-flatpak-helper

./helpers/%: ../sources/$@ sedscript
	sed --file=./sedscript.sed ../sources/$@ > $@

systemd: ./systemd/user/vpnslice-user-setup@.service ./systemd/system/vpnslice-system-setup@.service

./systemd/%: ../sources/$@ sedscript
	sed --file=./sedscript.sed ../sources/$@ > $@

polkit: ./polkit/vpnslice-user-helpers.rules

./polkit/%: ../sources/$@ sedscript
	sed --file=./sedscript.sed ../sources/$@ > $@

examples: ./examples/global.json ./examples/example.json

./examples/%: ../$@ sedscript
	sed --file=./sedscript.sed ../$@ > $@
