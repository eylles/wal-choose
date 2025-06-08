.POSIX:
PREFIX = ${HOME}/.local
BIN_LOC = $(DESTDIR)${PREFIX}/bin
LIB_LOC = $(DESTDIR)${PREFIX}/lib/wal-choose
.PHONY: install uninstall clean all

all: wal-choose wal-preview

wal-choose: wal-preview
	sed "s|@lib@|$(LIB_LOC)|" wal-choose.sh > wal-choose
	@chmod 755 wal-choose

wal-preview:
	cp wal-preview.sh wal-preview

install: all
	@mkdir -p $(BIN_LOC)
	@mkdir -p $(LIB_LOC)
	@cp -vf wal-choose $(BIN_LOC)/
	@cp -vf wal-preview $(LIB_LOC)/
	@echo Done installing
uninstall:
	@rm -vf $(BIN_LOC)/wal-choose
	@echo Done uninstalling

clean:
	rm -vf wal-choose wal-preview
