#!/bin/false dotme

# version: 2.1.20260509
# for licence/copyright, see: https://github.com/gedge/misc

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
	local target_bold="$(g_colr BOLD "$target")"
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
		g_err --pre ": " "Bad diff -u $target_bold $src"
		exit $res
	else
		[[ -n "$verbose" ]] && g_info --pre ": " "No diff -u $target_bold $src"
	fi
	return $res
}

# src_up { --0755 | --install | --lines | --ln $ln_to | --mkdir | --verbose } [ -- ] $src $target
function src_up() {
	local res=0 do_install= do_diff=1 do_cp= mode= lines= mk_dir= verbose=
	while [[ $1 == --* ]]; do
		local arg=$1; shift
		if   [[ $arg == --           ]]; then
			break
		elif [[ $arg =~ '^--[0-9]+$' ]]; then
			mode=${arg#--}
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
	local target_bold="$(g_colr BOLD "$target")"
	local dir=$(dirname "$target")
	if [[ -n "$do_install" ]]; then
		if [[ ! -d "$dir" ]]; then
			if [[ -z "$mk_dir" ]]; then
				g_warn "No target dir for $target_bold"
				return 2
			fi
			yorn "run: $(g_colr MAGENTA "mkdir -p $dir")" && \
				{ mkdir -p "$dir" || exit 1; }
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
				g_warn --pre ": " "Diff symlink $(g_colr white "$target → $ln_target") --- expected $(g_colr BOLD "$ln_to")"
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
			local pre_rm=; if [[ $do_cp == rm* ]] && pre_rm="rm \"$target\" &&"
			if [[ -n "$do_install" ]]; then
				g_info --pre ": " "$(g_colr MAGENTA Symlinking $src) from $target_bold to $ln_to"
				eval $pre_rm              ln -s "$ln_to" "$target" || exit 4
			else
				echo "$pre_rm${pre_rm:+ }"ln -s "$ln_to" "$target"
			fi
			do_cp=
		fi
	elif [[ -n $lines ]]; then
		if [[ ! -e "$target" ]]; then
			g_info --pre ": " "No file $target_bold for appending dotlines line - will copy"
			do_cp=cp
		elif [[ -L "$target" ]]; then
			g_warn --pre ": " "Symlink target $target_bold $(g_colr BLACK from $src)"
		else
			local xref=$(grep -o xref_'[^ ]*' < "$src" | sort -u)
			if [[ -z "$xref" ]]; then
				g_err --pre ": " "No xref $src"
				exit 44
			fi
			local xref_src=$(perl -nsE 'print if /$x/.../$x/' -- -x="$xref" < "$src")
			if [[ -z "$xref_src" ]]; then
				g_err --pre ": " "Bad xref $src"
				exit 22
			fi
			src_up_ensure_diff
			g_info --pre ": " "Checking $target_bold for dotlines lines with $(g_colr BLACK $xref)"
			res=0; $src_up_DIFF $DIFF_ARGS -u --label "$target"	<(perl -nsE 'print if /$x/.../$x/' -- -x="$xref" < "$target") \
							  --label "$src"	<(echo "$xref_src") || res=$?
			if [[ $res == 1 ]]; then
				# there is a diff
				if [[ -n "$do_install" ]]; then
					echo ": $(g_colr CYAN DIFF $src) Copying to $target_bold"
					local target_noo=${TMPDIR-/tmp}/sh_init_tgt.noo.$$
					{
						perl -nsE 'print unless /$x/.../$x/' -- -x="$xref" < "$target"
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
				g_err --pre ": " "Bad diff: $src"
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
			if [[ -z $mode ]]; then mode=0$(eval $STAT \"$src\"); fi
			echo ": $(g_colr MAGENTA Copying $src) to $target_bold $(g_colr BLACK "(mode: $mode)")"
			yorn		$this_install	-m \"$mode\" \"$src\" \"$target\" && \
				{ eval	$this_install	-m \"$mode\" \"$src\" \"$target\" || exit 4; }
			[[ -z "$verbose" ]] || echo ": $(\ls -l "$target")"
		else
			echo ":"	"$this_install	-m \"$mode\" \"$src\" \"$target\"" || exit 4
		fi
	fi
}
# vim: filetype=bash :
