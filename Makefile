.POSIX:
PREFIX = ${HOME}/.local
.PHONY: install uninstall cronadd
install:
	@chmod 755 wal-choose
	@mkdir -p ${DESTDIR}${PREFIX}/bin
	@cp -vf wal-choose ${DESTDIR}${PREFIX}/bin
	@echo Done installing
uninstall:
	@rm -vf ${DESTDIR}${PREFIX}/bin/wal-choose
	@echo Done uninstalling
