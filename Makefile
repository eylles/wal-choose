.POSIX:
PREFIX = ${HOME}/.local
BIN_LOC = $(DESTDIR)${PREFIX}/bin
.PHONY: install uninstall clean

wal-choose:
	cp wal-choose.sh wal-choose
	@chmod 755 wal-choose

install:
	@mkdir -p $(BIN_LOC)
	@cp -vf wal-choose $(BIN_LOC)
	@echo Done installing
uninstall:
	@rm -vf $(BIN_LOC)/wal-choose
	@echo Done uninstalling

clean:
	rm -vf wal-choose
