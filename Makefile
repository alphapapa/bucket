# ** Variables
PREFIX := /usr/local

DEST_SCRIPT := $(PREFIX)/bin/bucket
DEST_FISH_COMPLETION := $(PREFIX)/share/fish/completions/bucket.fish
DEST_FISH_GETOPTS := $(PREFIX)/share/fish/functions/getopts.fish
DEST_MAN_PAGE := $(PREFIX)/share/man/man1/bucket.1
DEST_README := $(PREFIX)/share/doc/bucket/README.org

INSTALL := install -D -p
INSTALL_DATA := $(INSTALL) -m 644

# ** Rules

# By default, install the Bash script, the Fish completions, and the man page
install: install-bash install-data

install-bash: install-data
	$(INSTALL) bucket.sh $(DEST_SCRIPT)

# Install the Fish script instead of the Bash script, and install the completions and man page
install-fish: install-data
	$(INSTALL) bucket.fish $(DEST_SCRIPT)
	$(INSTALL) getopts.fish $(DEST_FISH_GETOPTS)

install-data: install-fish-completions install-man-page install-readme

install-fish-completions:
	$(INSTALL) completions/bucket.fish $(DEST_FISH_COMPLETION)

install-man-page:
	$(INSTALL_DATA) bucket.1 $(DEST_MAN_PAGE)

install-readme:
	$(INSTALL_DATA) README.org $(DEST_README)

uninstall:
	rm -f $(DEST_SCRIPT) $(DEST_FISH_COMPLETION) $(DEST_FISH_GETOPTS) $(DEST_MAN_PAGE) $(DEST_README)
