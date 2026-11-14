# MK BBS (Free Pascal)
#
#   make                  build the programs (build/mk mklisten mkmon mkconfig mkread mkmenu mkusered mklc mklist mknodelist)
#   make test             build and run all the tests (./build.sh)
#   make install          install into /usr/local/bin and /etc/mkbbs, create the log
#                         directory, the mkbbs user and the systemd unit (as root)
#   make uninstall        remove the programs and the unit again (configuration,
#                         log directory and user stay)
#
# Variables:  PREFIX=/usr/local  BINDIR=$(PREFIX)/bin  SYSCONFDIR=/etc/mkbbs
#             LOGDIR=/var/log/mkbbs  MKUSER=mkbbs
#             UNITDIR=/etc/systemd/system  SYSUSERSDIR=/usr/lib/sysusers.d
#             SYSTEMD=auto|no    (no: no unit, no user)
#             DESTDIR=           (staging directory for packagers)
#   e.g.  make && sudo make install
#         make install PREFIX=$HOME/.local SYSCONFDIR=$HOME/.config/mkbbs

PREFIX     ?= /usr/local
BINDIR     ?= $(PREFIX)/bin
SYSCONFDIR ?= /etc/mkbbs
LOGDIR     ?= /var/log/mkbbs
MKUSER     ?= mkbbs
UNITDIR    ?= /etc/systemd/system
SYSUSERSDIR ?= /usr/lib/sysusers.d
SYSTEMD    ?= auto
DESTDIR    ?=

# true when this install may touch the system: staging, or running as root
PRIV = [ -n "$(DESTDIR)" ] || [ "$$(id -u)" = 0 ]
# true when the systemd pieces (unit, user) are wanted
WANTSD = [ "$(SYSTEMD)" != no ] && { [ -n "$(DESTDIR)" ] || { [ "$$(id -u)" = 0 ] && [ -d /run/systemd/system ]; }; }

PROGRAMS = mk mklisten mkmon mkconfig mkread mkmenu mkusered mklc mklist mknodelist

.PHONY: all test install uninstall clean

all: build/.built

# one stamp for the whole build: rebuilt when a source or the build script changed
build/.built: $(wildcard src/*.pas src/*.MK src/*.Def) build.sh
	./build.sh --build-only

test:
	./build.sh

install: build/.built
	install -d $(DESTDIR)$(BINDIR) $(DESTDIR)$(SYSCONFDIR)
	for p in $(PROGRAMS); do install -m 755 build/$$p $(DESTDIR)$(BINDIR)/$$p; done
	install -m 644 mklisten.example.json $(DESTDIR)$(SYSCONFDIR)/mklisten.example.json
	@if [ -e $(DESTDIR)$(SYSCONFDIR)/mklisten.json ]; then \
	  echo "keeping $(DESTDIR)$(SYSCONFDIR)/mklisten.json"; \
	else \
	  sed -e 's|"/usr/local/bin/mk"|"$(BINDIR)/mk"|' \
	      -e '/"logfile"/a\  "rundir": "/run/mkbbs",' \
	      mklisten.example.json > $(DESTDIR)$(SYSCONFDIR)/mklisten.json; \
	  chmod 600 $(DESTDIR)$(SYSCONFDIR)/mklisten.json; \
	  echo "created $(DESTDIR)$(SYSCONFDIR)/mklisten.json from the example: edit the paths and the sysop password"; \
	fi
	@if $(WANTSD); then \
	  install -d $(DESTDIR)$(SYSUSERSDIR) $(DESTDIR)$(UNITDIR); \
	  echo 'u $(MKUSER) - "MK BBS" - -' > $(DESTDIR)$(SYSUSERSDIR)/mkbbs.conf; \
	  sed -e 's|@BINDIR@|$(BINDIR)|g' -e 's|@SYSCONFDIR@|$(SYSCONFDIR)|g' -e 's|@MKUSER@|$(MKUSER)|g' \
	      mklisten.service.in > $(DESTDIR)$(UNITDIR)/mklisten.service; \
	  chmod 644 $(DESTDIR)$(UNITDIR)/mklisten.service; \
	  echo "installed $(DESTDIR)$(UNITDIR)/mklisten.service"; \
	  if [ -z "$(DESTDIR)" ]; then \
	    if command -v systemd-sysusers >/dev/null 2>&1; then systemd-sysusers $(SYSUSERSDIR)/mkbbs.conf; \
	    else echo "create the user yourself:  useradd --system $(MKUSER)"; fi; \
	    systemctl daemon-reload; \
	  fi; \
	fi
	@if $(PRIV); then \
	  install -d -m 755 $(DESTDIR)$(LOGDIR); \
	  echo "log directory $(DESTDIR)$(LOGDIR)"; \
	  if [ -z "$(DESTDIR)" ] && id -u $(MKUSER) >/dev/null 2>&1; then \
	    chown $(MKUSER):$(MKUSER) $(LOGDIR); \
	    chgrp $(MKUSER) $(SYSCONFDIR)/mklisten.json && chmod 640 $(SYSCONFDIR)/mklisten.json; \
	  fi; \
	else \
	  echo "not root: create the log directory $(LOGDIR) yourself"; \
	fi
	@echo "installed $(PROGRAMS) in $(DESTDIR)$(BINDIR)"
	@if $(WANTSD) && [ -z "$(DESTDIR)" ]; then \
	  echo "next: edit $(SYSCONFDIR)/mklisten.json, then   systemctl enable --now mklisten"; \
	fi

uninstall:
	for p in $(PROGRAMS); do rm -f $(DESTDIR)$(BINDIR)/$$p; done
	rm -f $(DESTDIR)$(SYSCONFDIR)/mklisten.example.json
	rm -f $(DESTDIR)$(UNITDIR)/mklisten.service $(DESTDIR)$(SYSUSERSDIR)/mkbbs.conf
	@if [ -z "$(DESTDIR)" ] && [ "$$(id -u)" = 0 ] && command -v systemctl >/dev/null 2>&1; then systemctl daemon-reload; fi
	@echo "removed the programs and the unit; $(DESTDIR)$(SYSCONFDIR)/mklisten.json, $(DESTDIR)$(LOGDIR) and the $(MKUSER) user are left alone"

clean:
	rm -rf build
