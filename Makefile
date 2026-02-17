SHELL=zsh

VISUAL?=vim
DIFF?=colordiff
VERBOSE?=
mk=$(MAKE) --no-print-directory
TARGET_DIR?=/usr/local/bin
SOURCE_GLIB=lib/g_lib.sh
SOURCE_SRCUP=lib/src_up.sh
SOURCE_FILES?=$(SOURCE_GLIB) $(SOURCE_SRCUP)

all:
	:

edit:
	$(VISUAL) Makefile $(SOURCE_FILES) README.md LICENSE.md

install diff:
	@for i in $(SOURCE_FILES); do								\
		$(mk) $(@)1 VERBOSE=$(VERBOSE) SRC="$$i" TARGET="$(TARGET_DIR)/$${i##*/}";	\
	done

# $(mk) install1 TARGET=... SRC=... (optionally LN_TO=tgt when want symlink to tgt, not cp SRC)
sane:
	@if [[   -z "$(SRC)" || -z "$(TARGET)" ]]; then echo Missing SRC/TARGET; exit 1; fi
	@if [[ ! -e "$(SRC)" && ! -L "$(SRC)"  ]]; then echo No file $(SRC);     exit 1; fi
install1 diff1: sane
	@args=();						\
	[[ -n "$(VERBOSE)" ]] && args+=("--verbose");		\
	[[ $@ == install*  ]] && args+=("--install");		\
	source $(SOURCE_SRCUP);					\
		src_up --0444 "$${args[@]}" "$(SRC)" "$(TARGET)"

test:
	-@         source $(SOURCE_GLIB); g_opts strict extro; echo -n "Test 1 "; ls "does not exist"
	-@bash -c 'source $(SOURCE_GLIB); g_opts strict extro; echo -n "Test 2 "; grep "yes" <<<"no"  '
	-@         source $(SOURCE_GLIB); g_opts strict extro; echo -n "Test 3 "; "cmd does not exist"
