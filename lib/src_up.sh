#!/bin/false dotme

# version: 2.1.20261103
# for licence/copyright, see: https://codeberg.org/gedge/misc

if [[ -f lib/g_lib.sh && -f lib/src_up.sh && -d .git ]]; then
	# use local version when developing
	source lib/g_lib.sh
else
	source g_lib.sh
fi

case "$(uname -s)" in
	(Linux)
		STAT="stat -c '%a'"
		GROUP=root
		;;
	(*)
		# e.g. Darwin FreeBSD
		STAT="stat -f '%Mp%Lp'"
		GROUP=wheel
		;;
esac

function src_up_ensure_diff() {
	[[ -n ${src_up_DIFF-} ]] && return
	if [[ -z ${DIFF-} ]]; then
		src_up_DIFF=diff
		which colordiff > /dev/null 2>&1 && src_up_DIFF=colordiff
	else
		src_up_DIFF=$DIFF
	fi
}

function src_up_ensure_install() {
	[[ -n ${src_up_INSTALL-} ]] && return
	src_up_INSTALL=${INSTALL:-install -p}
	src_up_ROOT_INSTALL="$src_up_INSTALL -o '$USER' -g '$GROUP'"
}

function mk_safe() {
	sed 's![^-a-zA-Z0-9 /_.,@%:]!\\&!g' <<<"$1" | tr -d '\n'
}

# do_diff returns 1 when diff returns 1 (the files differ)
function do_diff() {
	local verbose=
	while [[ $1 == --* ]]; do
		local arg=$1; shift
		if   [[ $arg == --           ]]; then
			break
		elif [[ $arg == --verbose    ]]; then
			verbose=$arg
		else
			g_err --pre ": " "Bad option: '$arg'"
			return 2
		fi
	done
	local src=$1 target=$2
	local target_bold="$(g_colr bold "$target")"
	src_up_ensure_diff
	local res=0; $src_up_DIFF -q "$target" "$src" > /dev/null || res=$?
	if [[ $res == 1 ]]; then
		if [[ "$target" -nt "$src" ]]; then
			$src_up_DIFF $DIFF_ARGS -u "$src" "$target"
			g_warn --pre ": " "target newer,     $(g_colr RED pull): cp -ip \"$target_bold\" \"$src\""
			g_warn --pre ": " "or:  force older, push:"             "cp -ip \"$src\" \"$target_bold\""
			res=2
		else
			$src_up_DIFF $DIFF_ARGS -u "$target" "$src"
		fi
	elif [[ $res -ne 0 ]]; then
		g_err --pre ": " "bad diff -u $target_bold $src"
		exit $res
	else
		[[ -n "$verbose" ]] && g_info --pre ": " "No diff -u $target_bold $src"
	fi
	return $res
}

# src_up { --0755 | --batch | --install | --lines | --ln $ln_to | --mkdir | --verbose } [ -- ] $src $target
# --lines removes any "blah xref_ook blah\n...\nfoo xref_ook foo\n" in src, and appends to tgt the new xref_ook lines in src
function src_up() {
	local res=0 do_install= do_diff=1 do_cp= mode= lines= mk_dir= verbose= confirm=1
	while [[ $1 == --* ]]; do
		local arg=$1; shift
		if   [[ $arg == --           ]]; then
			break
		elif [[ $arg =~ '^--[0-9]+$' ]]; then
			mode=${arg#--}
		elif [[ $arg == --batch    ]]; then
			confirm=
		elif [[ $arg == --install    ]]; then
			do_install=1
		elif [[ $arg == --lines      ]]; then
			lines=1
		elif [[ $arg == --ln         ]]; then
			ln_to=$1
			shift
		elif [[ $arg == --mkdir      ]]; then
			mk_dir=1
		elif [[ $arg == --verbose    ]]; then
			verbose=$arg
		else
			g_err --pre ": " "Bad option: '$arg'"
			return 2
		fi
	done
	local src=$1 target=$2
	local target_bold="$(g_colr bold "$target")"
	local dir=$(dirname "$target")
	if [[ -n "$do_install" ]]; then
		if [[ ! -d "$dir" ]]; then
			if [[ -z "$mk_dir" ]]; then
				g_warn "No target dir for $target_bold"
				return 2
			fi
			if [[ -n $confirm ]]; then
				yorn "run: $(g_colr MAGENTA "mkdir -p $dir")" && \
					{	mkdir -p "$dir" || exit 1; }
			else
						mkdir -p "$dir" || exit 1
			fi
		fi
		if [[ ! -w "$dir" ]]; then g_warn "Cannot write to $dir"; fi
	fi

	if [[ -L "$src" || -n "$ln_to" ]]; then
		if [[ -z "$ln_to" ]]; then
			ln_to=$(readlink "$src")
		fi
		if [[ "$ln_to" == $dir/* ]]; then ln_to=${ln_to#$dir/}; fi
		if [[ -L "$target" ]]; then
			local ln_target="$(readlink "$target")"
			if [[ "$ln_to" != "$ln_target" ]]; then
				g_warn --pre ": " "Diff symlink $(g_colr white "$target → $ln_target") --- expected $(g_colr bold "$ln_to")"
				do_cp=rmln
			else
				[[ -n "$verbose" ]] && g_info --pre ": " "No symlink diff $target_bold → $ln_to"
			fi
		elif [[ ! -e "$target" ]]; then
			g_info --pre ": " "No symlink $target_bold"
			do_cp=ln
		else
			g_warn --pre ": " "skipping existing non-symlink: $target_bold"
			do_diff $verbose "$src" "$target" || res=$?
			[[ $res -eq 1 ]] && do_cp=cp
		fi
		if [[ -n $do_cp ]]; then
			local pre_rm=; [[ $do_cp == rm* ]] && pre_rm="rm \"$target\" &&"
			if [[ -n "$do_install" ]]; then
				g_info --pre ": " "$(g_colr MAGENTA Symlinking $src) from $target_bold to $ln_to"
				local target_safe="$(mk_safe "$target")"
				local ln_to_safe="$(mk_safe "$ln_to")"
				eval $pre_rm              ln -s "$ln_to_safe" "$target_safe" || exit 4
			else
				echo "$pre_rm${pre_rm:+ }"ln -s "$ln_to" "$target"
			fi
			do_cp=
		fi
	elif [[ -n $lines ]]; then
		if [[ ! -f "$src" ]]; then
			g_err --pre ": " "no file: $src"
			exit 44
		fi
		local xrefs=( $(grep -o xref_'[a-zA-Z0-9_]*' < "$src" | sort) )
		if [[ ${#xrefs[*]} -ne 2 || ${xrefs[0]} != ${xrefs[1]} ]]; then
			g_err --pre ": " "no xref_* pair in $src (got: ${xrefs[*]})"
			exit 44
		fi
		local xref_src="$(perl -nsE 'print if /$x/.../$x/' -- -x="${xrefs[0]}" < "$src")"
		if [[ -z "$xref_src" ]]; then
			g_err --pre ": " "bad xref_* in $src"
			exit 22
		fi
		if [[ ! -e "$target" ]]; then
			g_info --pre ": " "no file $target_bold for appending xref lines - will copy"
			do_cp=cp
		elif [[ -L "$target" ]]; then
			g_warn --pre ": " "symlink target $target_bold $(g_colr BLACK from $src)"
		else
			src_up_ensure_diff
			g_info --pre ": " "checking $target_bold for xref lines with $(g_colr BLACK ${xrefs[0]})"
			res=0; $src_up_DIFF $DIFF_ARGS -u	--label "$target"	<(perl -nsE 'print if /$x/.../$x/' -- -x="${xrefs[0]}" < "$target") \
								--label "$src"		<(echo "$xref_src") || res=$?
			if [[ $res == 1 ]]; then
				# there is a diff
				if [[ -n "$do_install" ]]; then
					echo ": $(g_colr CYAN DIFF $src) Copying to $target_bold"
					local target_noo=${TMPDIR-/tmp}/sh_init_tgt.noo.$$
					{
						perl -nsE 'print unless /$x/.../$x/' -- -x="${xrefs[0]}" < "$target"
						cat "$src"
					} > "$target_noo"
					res=0; $src_up_DIFF $DIFF_ARGS -u "$target" --label tmp-chunk "$target_noo"	|| res=$?
					if [[ $res == 1 ]]; then
						if ! cat "$target_noo" >| "$target"; then
							rm "$target_noo"
							exit 55
						fi
						rm "$target_noo"
					else
						g_err --pre ": " "DIFF res=$res $src $(g_colr BLACK "for") $target_bold"
						rm "$target_noo"
						exit 77
					fi
				else
					echo ": $(g_colr CYAN DIFF $src) $target"
				fi
			elif [[ $res != 0 ]]; then
				g_err --pre ": " "bad diff: $src"
				exit $res
			fi
		fi
	else
		if [[ ! -e "$target" ]]; then
			g_info --pre ": " "No file $target_bold $(g_colr BLACK "will copy")"
			do_cp=cp
		else
			do_diff $verbose "$src" "$target" || res=$?
			[[ $res -eq 1 ]] && do_cp=cp
		fi
	fi
	if [[ -n $do_cp ]]; then
		src_up_ensure_install
		local this_install=$src_up_INSTALL
		[[ $USER == root ]] && this_install=$src_up_ROOT_INSTALL
		if [[ -n "$do_install" ]]; then
			local target_safe="$(mk_safe "$target")"
			local src_safe="$(mk_safe "$src")"
			if [[ -z $mode ]]; then mode=0$(eval $STAT \"$src_safe\"); fi
			echo ": $(g_colr MAGENTA Copying $src) to $target_bold $(g_colr BLACK "(mode: $mode)")"
			if [[ -z $confirm ]] || yorn	$this_install -m \"$mode\" \"$src_safe\" \"$target_safe\"; then
				{ eval			$this_install -m \"$mode\" \"$src_safe\" \"$target_safe\" || exit 4; }
			fi
			[[ -z "$verbose" ]] || echo ": $(\ls -l "$target")"
		else
			echo ":"	"$this_install	-m \"$mode\" \"$src\" \"$target\"" || exit 4
		fi
	fi
}
# vim: filetype=bash :
