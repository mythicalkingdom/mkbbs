# MK BBS (Free Pascal)
#
#   make                  build the programs (build/mk mklisten mkmon mkconfig mkread)
#   make test             build and run all the tests (./build.sh)
#   make install          install into /usr/local/bin and /etc/mkbbs
#   make uninstall        remove the programs again (the configuration stays)
#
# Variables:  PREFIX=/usr/local  BINDIR=$(PREFIX)/bin  SYSCONFDIR=/etc/mkbbs
#             DESTDIR=           (staging directory for packagers)
#   e.g.  make && sudo make install
#         make install PREFIX=$HOME/.local SYSCONFDIR=$HOME/.config/mkbbs

PREFIX     ?= /usr/local
BINDIR     ?= $(PREFIX)/bin
SYSCONFDIR ?= /etc/mkbbs
DESTDIR    ?=

PROGRAMS = mk mklisten mkmon mkconfig mkread

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
	  sed 's|"/usr/local/bin/mk"|"$(BINDIR)/mk"|' mklisten.example.json > $(DESTDIR)$(SYSCONFDIR)/mklisten.json; \
	  chmod 600 $(DESTDIR)$(SYSCONFDIR)/mklisten.json; \
	  echo "created $(DESTDIR)$(SYSCONFDIR)/mklisten.json from the example: edit the paths and the sysop password"; \
	fi
	@echo "installed $(PROGRAMS) in $(DESTDIR)$(BINDIR)"

uninstall:
	for p in $(PROGRAMS); do rm -f $(DESTDIR)$(BINDIR)/$$p; done
	rm -f $(DESTDIR)$(SYSCONFDIR)/mklisten.example.json
	@echo "removed the programs; $(DESTDIR)$(SYSCONFDIR)/mklisten.json (your configuration) is left alone"

clean:
	rm -rf build
