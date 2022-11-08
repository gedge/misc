SHELL=zsh

VISUAL?=vim
DIFF?=colordiff
VERBOSE?=
mk=$(MAKE) --no-print-directory
TARGET_DIR?=/usr/local/bin
SOURCE_GLIB=lib/g_lib.sh
SOURCE_SRCUP=lib/src_up.sh
SOURCE_FILES=$(SOURCE_GLIB) $(SOURCE_SRCUP)

all:
	:

edit:
	$(VISUAL) $(SOURCE_FILES)

install diff:
	@for i in $(SOURCE_FILES); do				\
		$(mk) $(@)1 VERBOSE=$(VERBOSE) SRC="$$i" TARGET="$(TARGET_DIR)/$${i##*/}";	\
	done

# $(mk) install1 TARGET=... SRC=... (optionally LN_TO=tgt when want symlink to tgt, not cp SRC)
install1 diff1:
	@if [[ -z "$(SRC)" || -z "$(TARGET)"  ]]; then echo Missing SRC/TARGET; exit 1; fi
	@if [[ ! -e "$(SRC)" && ! -L "$(SRC)" ]]; then echo No file $(SRC);     exit 1; fi
	@. $(SOURCE_SRCUP);	\
	src_up "$@" "$(SRC)" "$(TARGET)" "$(VERBOSE)" "$(LN_TO)"
