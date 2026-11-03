SHELL=zsh

VISUAL?=vim
DIFF?=colordiff
VERBOSE?=
mk=$(MAKE) --no-print-directory
TARGET_DIR?=/usr/local/bin
SOURCE_GLIB=lib/g_lib.sh
SOURCE_SRCUP=lib/src_up.sh
SOURCE_FILES?=$(SOURCE_GLIB) $(SOURCE_SRCUP)
D_SU=source $(SOURCE_SRCUP)
D_GL=source $(SOURCE_GLIB)
GLIB_OPTS=$(D_GL); g_opts
T=tmp/t_

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
test: test-glib test-srcup
test-glib:
	@          $(D_GL);               g_info "recurse test $$(g_colr -r magenta pre-blue $$(g_colr blue this is blue) post-blue-should-be-magenta)."
	@          $(D_GL);               g_info "bold test $$(g_colr bold bold) should see bold."
	@          $(GLIB_OPTS) info;     g_info "Zsh  test: no pre, also $$(g_colr black_on_white BOW) should seen BoW"
	@          $(GLIB_OPTS) info;     g_info --pre " with pre " "Zsh" "test \" with pre \""
	@bash -c  '$(GLIB_OPTS) info;     g_info "Bash test: no pre"'
	@bash -c  '$(GLIB_OPTS) info;     g_info --pre " with pre " "Bash test: \" with pre \""'
	@          $(D_GL);               g_info "test of $$(g_colr CYAN_on_blue ls)        fail trap: expect error..."
	-@         $(GLIB_OPTS) strict extro; echo -n "Test 1 "; ls "does not exist"
	@          $(D_GL);               g_info "test of $$(g_colr CYAN_on_blue yes)       fail trap: expect error..."
	-@bash -c '$(GLIB_OPTS) strict extro; echo -n "Test 2 "; grep "yes" <<<"no"'
	@          $(D_GL);               g_info "test of $$(g_colr CYAN_on_blue not-found) fail trap: expect error..."
	-@         $(GLIB_OPTS) strict extro; echo -n "Test 3 "; "cmd does not exist"
	@          $(D_GL);               g_warn "test g_warn (next line should be non-stdout warn)"
	@          $(D_GL);               g_warn "test g_warn has colour despite non-stdout" > /dev/null
	@          $(GLIB_OPTS)     colr; g_info    "test g_info colr     has colour"
	@          $(GLIB_OPTS)     colr; g_info -C "test g_info colr     lacks colour when -C"
	@          $(GLIB_OPTS)   nocolr; g_info    "test g_info nocolr   lacks colour"
	@          $(GLIB_OPTS)   nocolr; g_info -c "test g_info nocolr   has colour when -c"
	@          $(GLIB_OPTS) autocolr; g_info    "test g_info autocolr has colour"
	@          $(GLIB_OPTS) autocolr; g_info    "test g_info autocolr lacks colour when non-stdout" | read str; echo "$$str $$(g_colr -c GREEN "<--no colour--")"
	@          $(D_GL);               g_info "$$(g_colr CYAN done) g_lib tests"
test-srcup:
	[[ ! -d tmp ]] || rm -r tmp
	@$(D_SU);   src_up                           $(T)i0.src $(T)i0; [[ ! -f $(T)i0 ]]	# no src
	@$(D_SU); ! src_up                           /dev/null  $(T)i1; [[ ! -f $(T)i1 ]]	# should not create - no --install
	@$(D_SU); ! src_up --install                 /dev/null  $(T)i2; [[ ! -f $(T)i2 ]]	# should not create - no --mkdir
	@$(D_SU);   src_up --install --mkdir         /dev/null  $(T)i3; [[   -f $(T)i3 ]]	# ok
	@$(D_SU);   src_up --install --mkdir --batch /dev/null  $(T)i4; [[   -f $(T)i4 ]]	# ok
	@! bash -c '$(D_SU);                                src_up           --lines $(T)l1.src $(T)l1' && [[ ! -f $(T)l1 ]]	# no source
	@! bash -c '$(D_SU); date > $(T)l2.src;             src_up           --lines $(T)l2.src $(T)l2' && [[ ! -f $(T)l2 ]]	# source, no xref, no --install
	@! bash -c '$(D_SU); date > $(T)l3.src;             src_up --install --lines $(T)l3.src $(T)l3' && [[ ! -f $(T)l3 ]]	# source, no xref
	@! bash -c '$(D_SU); echo "pre-ex l4" > $(T)l4.src; src_up           --lines $(T)l4.src $(T)l4' && [[ ! -f $(T)l4 ]]	# no --install
	@! bash -c '$(D_SU); echo "pre-ex l5" > $(T)l5;     src_up --install --lines $(T)l5.src $(T)l5' && diff -u $(T)l5 <(echo "pre-ex l5")	# no src, tgt exists, no change
	@l6x=$$'# xref_l6 starts\nthis 1\nthat 2\n# xref_l6 ends\n'; echo -n "$$l6x" > $(T)l6.src;				\
	   bash -c '$(D_SU);                                src_up           --lines $(T)l6.src $(T)l6' && [[ ! -f $(T)l6 ]]	# no install, no tgt
	@l7x=$$'# xref_l7 starts\nthis 1\nthat 2\n# xref_l7 ends\n'; echo -n "$$l7x" > $(T)l7.src;				\
	   bash -c '$(D_SU);                                src_up --install --lines $(T)l7.src $(T)l7' && diff -u $(T)l7 <(echo -n "$$l7x")	# no tgt, ok
	@l8x=$$'# xref_l8 starts\nthis 1\nthat 2\n# xref_l8 ends\n';                      echo -n "$$l8x"   > $(T)l8.src;	\
	   l8tgt=$$'abc\n# xref_l8 old\nthis 1tgt\nthat 2tgt\n# xref_l8_broken ends old\ndef\n'; echo -n "$$l8tgt" > $(T)l8;	\
	 ! bash -c '$(D_SU);                                src_up           --lines $(T)l8.src $(T)l8' && diff -u $(T)l8 <(echo -n "$${l8tgt}")	# tgt already has xref, but not pair
	@l9x=$$'# xref_l9 starts\nthis 1\nthat 2\n# xref_l9 ends\n';                      echo -n "$$l9x"   > $(T)l9.src;	\
	   l9tgt=$$'abc\n# xref_l9 old\nthis 1tgt\nthat 2tgt\n# xref_l9 ends old\ndef\n'; echo -n "$$l9tgt" > $(T)l9;		\
	   bash -c '$(D_SU);                                src_up --install --lines $(T)l9.src $(T)l9' && diff -u $(T)l9 <(echo -en "abc\ndef\n$${l9x}")	# tgt already has xref, ok
	@$(D_GL);   g_info "$$(g_colr CYAN done) src_up tests"
