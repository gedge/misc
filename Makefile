SHELL=zsh

VISUAL?=vim
DIFF?=colordiff
VERBOSE?=
mk=$(MAKE) --no-print-directory
TARGET_DIR?=/usr/local/bin
SOURCE_GLIB=lib/g_lib.sh
SOURCE_SRCUP=lib/src_up.sh
SOURCE_FILES?=$(SOURCE_GLIB) $(SOURCE_SRCUP)
DOT_GLIB=source $(SOURCE_GLIB)
GLIB_OPTS=$(DOT_GLIB); g_opts

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

# assumes make shell is zsh (see above)
test:
	@          $(DOT_GLIB);               g_info "recurse test $$(g_colr -r magenta pre-blue $$(g_colr blue this is blue) post-blue-should-be-magenta)."
	@          $(DOT_GLIB);               g_info "bold test $$(g_colr bold bold) should see bold."
	@          $(GLIB_OPTS) info;         g_info "Zsh  test: no pre, also $$(g_colr black_on_white BOW) should seen BoW"
	@          $(GLIB_OPTS) info;         g_info --pre " with pre " "Zsh" "test with pre"
	@bash -c  '$(GLIB_OPTS) info;         g_info "Bash test: no pre"'
	@bash -c  '$(GLIB_OPTS) info;         g_info --pre " with pre " "Bash test: with pre"'
	@          $(DOT_GLIB);               g_info "test of $$(g_colr CYAN_on_blue ls)        fail trap: expect error..."
	-@         $(GLIB_OPTS) strict extro; echo -n "Test 1 "; ls "does not exist"
	@          $(DOT_GLIB);               g_info "test of $$(g_colr CYAN_on_blue yes)       fail trap: expect error..."
	-@bash -c '$(GLIB_OPTS) strict extro; echo -n "Test 2 "; grep "yes" <<<"no"'
	@          $(DOT_GLIB);               g_info "test of $$(g_colr CYAN_on_blue not-found) fail trap: expect error..."
	-@         $(GLIB_OPTS) strict extro; echo -n "Test 3 "; "cmd does not exist"
	@          $(DOT_GLIB);               g_info "$$(g_colr CYAN done) tests"
