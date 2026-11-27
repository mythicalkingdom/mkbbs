# MK BBS (Free Pascal)
#
#   make                  build the programs (build/mk mklisten mkmon mkconfig mkread mkmenu mkusered mklc mklistmsgarea mknodelist mknodeidx mkcfgcvt mkbinkcfg mklower mktoss mkhatch mkbbsssh mkqwk mkqwkcfg mkcat mkdraw mkpwconv mkfreq mkevents mkbackup mkmaint mkstats mkuserpurge mkfilecheck mkuserpack mkapi mkapitoken mksetup mkcheck mkmsgconv mkchatctl mkconnect)
#   make test             build and run all the tests (./build.sh)
#   make install          install into /usr/local/bin and /etc/mkbbs, create the log
#                         directory, the mkbbs user and the systemd unit (as root)
#   make uninstall        remove the programs and the unit again (configuration,
#                         log directory and user stay)
#   make deb              a Debian package, build/mkbbs_<version>_<arch>.deb (packaging/mkdeb.sh)
#   make deb-mkdraw       the package of mkdraw and mkcat alone, build/mkdraw_<version>_<arch>.deb (packaging/mkdeb-draw.sh)
#   make install-draw     only mkdraw, mkcat, their manual pages and the example codes.mkd
#
# Variables:  PREFIX=/usr/local  BINDIR=$(PREFIX)/bin  SYSCONFDIR=/etc/mkbbs
#             LOGDIR=/var/log/mkbbs  MKUSER=mkbbs
#             UNITDIR=/etc/systemd/system  SYSUSERSDIR=/usr/lib/sysusers.d
#             SYSTEMD=auto|no    (no: no unit, no user)
#             DESTDIR=           (staging directory for packagers)
#             MKBINK=../mkbink   the binkp mailer project (a separate repository): when it is there, its
#                                program is built and installed too (mklisten runs it, see "mailer" in
#                                mklisten.example.json)
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
MKBINK     ?= ../mkbink

# true when this install may touch the system: staging, or running as root
PRIV = [ -n "$(DESTDIR)" ] || [ "$$(id -u)" = 0 ]
# true when the systemd pieces (unit, user) are wanted
WANTSD = [ "$(SYSTEMD)" != no ] && { [ -n "$(DESTDIR)" ] || { [ "$$(id -u)" = 0 ] && [ -d /run/systemd/system ]; }; }

PROGRAMS = mk mklisten mkmon mkconfig mkread mkmenu mkusered mklc mklistmsgarea mknodelist mknodeidx mkcfgcvt mkbinkcfg mklower mktoss mkhatch mkbbsssh mkqwk mkqwkcfg mkcat mkdraw mkpwconv mkfreq mkevents mkbackup mkmaint mkstats mkuserpurge mkfilecheck mkuserpack mkapi mkapitoken mksetup mkcheck mkmsgconv mkchatctl mkconnect

.PHONY: all test install install-draw uninstall clean lang deb deb-mkdraw

all: build/.built

# one stamp for the whole build: rebuilt when a source or the build script changed
build/.built: $(wildcard src/*.pas src/*.MK src/*.Def) build.sh
	./build.sh --build-only

# language files from lang/*.TXT (lang/MKMENU.LC goes into the BBS directory)
lang: build/.built
	build/mklc lang/MKMENU.TXT
	build/mklc lang/AMERICAN.TXT
	build/mklc lang/ENGLISH.TXT

test:
	./build.sh

# mkdraw and mkcat alone (what the package mkdraw has): the programs, the manual pages, the example list of screen codes
install-draw: build/.built
	install -d $(DESTDIR)$(BINDIR) $(DESTDIR)$(PREFIX)/share/man/man1 $(DESTDIR)$(PREFIX)/share/mkdraw
	install -m 755 build/mkdraw build/mkcat $(DESTDIR)$(BINDIR)/
	install -m 644 man/mkdraw.1 man/mkcat.1 $(DESTDIR)$(PREFIX)/share/man/man1/
	install -m 644 contrib/mkdraw/codes.mkd $(DESTDIR)$(PREFIX)/share/mkdraw/codes.mkd

install: build/.built
	$(MAKE) -s -o build/.built install-draw
	install -d $(DESTDIR)$(BINDIR) $(DESTDIR)$(SYSCONFDIR)
	for p in $(PROGRAMS); do install -m 755 build/$$p $(DESTDIR)$(BINDIR)/$$p; done
	@if [ -f $(MKBINK)/Makefile ]; then \
	  $(MAKE) -s -C $(MKBINK) build/mkbink && install -m 755 $(MKBINK)/build/mkbink $(DESTDIR)$(BINDIR)/mkbink \
	    && echo "installed mkbink from $(MKBINK)"; \
	else \
	  echo "mkbink (the binkp mailer) not found in $(MKBINK): the mailer is not installed (make install MKBINK=<its directory>)"; \
	fi
	install -m 755 tools/mkdosdoor $(DESTDIR)$(BINDIR)/mkdosdoor
	install -d $(DESTDIR)$(PREFIX)/share/mkbbs/hubs $(DESTDIR)$(PREFIX)/share/mkbbs/lang $(DESTDIR)$(PREFIX)/share/mkbbs/games
	install -m 644 lang/AMERICAN.lc lang/ENGLISH.lc lang/MKMENU.lc $(DESTDIR)$(PREFIX)/share/mkbbs/lang/ 2>/dev/null || true
	install -m 644 games/cowsandbulls.pas $(DESTDIR)$(PREFIX)/share/mkbbs/games/
	install -m 644 hubs/*.scr $(DESTDIR)$(PREFIX)/share/mkbbs/hubs/
	install -d $(DESTDIR)$(PREFIX)/share/mkbbs/ssh
	install -m 644 contrib/ssh/* $(DESTDIR)$(PREFIX)/share/mkbbs/ssh/
	install -d $(DESTDIR)$(PREFIX)/share/mkbbs/qwk
	install -m 755 contrib/qwk/*.sh $(DESTDIR)$(PREFIX)/share/mkbbs/qwk/
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
	for p in $(PROGRAMS) mkbink mkdosdoor; do rm -f $(DESTDIR)$(BINDIR)/$$p; done
	rm -f $(DESTDIR)$(SYSCONFDIR)/mklisten.example.json
	rm -f $(DESTDIR)$(PREFIX)/share/man/man1/mkdraw.1 $(DESTDIR)$(PREFIX)/share/man/man1/mkcat.1
	rm -rf $(DESTDIR)$(PREFIX)/share/mkdraw
	rm -f $(DESTDIR)$(UNITDIR)/mklisten.service $(DESTDIR)$(SYSUSERSDIR)/mkbbs.conf
	@if [ -z "$(DESTDIR)" ] && [ "$$(id -u)" = 0 ] && command -v systemctl >/dev/null 2>&1; then systemctl daemon-reload; fi
	@echo "removed the programs and the unit; $(DESTDIR)$(SYSCONFDIR)/mklisten.json, $(DESTDIR)$(LOGDIR) and the $(MKUSER) user are left alone"

deb: build/.built
	packaging/mkdeb.sh

# build/mkdraw_<version>_<arch>.deb: mkdraw and mkcat for systems that have no BBS (packaging/mkdeb-draw.sh)
deb-mkdraw: build/.built
	packaging/mkdeb-draw.sh

clean:
	rm -rf build
