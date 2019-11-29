
ifndef INSTALLDIR
INSTALLDIR = installvendorlib
endif

MODULEDIR = $(DESTDIR)$(shell eval "`perl -V:${INSTALLDIR}`"; echo "$$${INSTALLDIR}")/Kapalarm
BINDIR    = $(DESTDIR)/usr/local/bin
SBINDIR   = $(DESTDIR)/usr/local/sbin
LOGDIR    = $(DESTDIR)/var/log/kapalarm
ETCDIR    = $(DESTDIR)/etc
CONFDIR   = $(ETCDIR)/kapalarm

install_common:
		mkdir -p $(DESTDIR) $(MODULEDIR) $(BINDIR) $(SBINDIR) $(LOGDIR) $(ETCDIR) $(CONFDIR)
		cp -r lib/Kapalarm/* $(MODULEDIR)
		id kapacitor && chown kapacitor.kapacitor $(LOGDIR)
		[ -f $(CONFDIR)/kap.conf ] || cp etc/kap.conf $(CONFDIR)

install_exec: install_exec
		cp -f bin/kap-exec ${BINDIR}

install_white: install_white
		cp -f bin/kap-white ${BINDIR}

install_status: install_status
		cp -f bin/kap-status ${BINDIR}

install: install_common install_exec install_white install_status
