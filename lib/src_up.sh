#!/bin/false dotme

# version: 2.0.20260104
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
			echo ": $(g_colr RED Bad option:) '$arg'" >&2
			return 2
		fi
	done
	local src=$1 target=$2
	src_up_ensure_diff
	local res=0; $src_up_DIFF -q "$target" "$src" > /dev/null || res=$?
	if [[ $res == 1 ]]; then
		if [[ "$target" -nt "$src" ]]; then
			$src_up_DIFF -u "$src" "$target"
			echo ": $(g_colr RED    "WARNING: target newer"), pull: cp -ip \"$target\" \"$src\""
			echo ": $(g_colr YELLOW "     or:  force older"), push: cp -ip \"$src\" \"$target\""
			res=2
		else
			$src_up_DIFF -u "$target" "$src"
		fi
	elif [[ $res -ne 0 ]]; then
		echo ": $(g_colr RED Error: Bad diff) -u $target $src"
		exit $res
	else
		[[ -n "$verbose" ]] && echo ": INFO No diff -u $target $src"
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
			echo ": $(g_colr RED Bad option:) '$arg'" >&2
			return 2
		fi
	done
	local src=$1 target=$2
	local dir=$(dirname "$target")
	if [[ -n "$do_install" ]]; then
		if [[ ! -d "$dir" ]]; then
			if [[ -z "$mk_dir" ]]; then
				g_warn "No target dir for $(g_colr BOLD $target)"
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
			if [[ "$ln_to" != "$(readlink "$target")" ]]; then
				echo ": $(g_colr YELLOW WARN Diff symlink) $target → $(readlink "$target") --- expected $ln_to"
				do_cp=rmln
			else
				[[ -n "$verbose" ]] && echo ": INFO No symlink diff $target → $ln_to"
			fi
		elif [[ ! -e "$target" ]]; then
			echo ": INFO No symlink $target"
			do_cp=ln
		else
			echo ": $(g_colr YELLOW WARN skipping existing) non-symlink: $target"
			do_diff $verbose "$src" "$target" || res=$?
			[[ $res -eq 1 ]] && do_cp=cp
		fi
		if [[ -n $do_cp ]]; then
			local pre_rm=; if [[ $do_cp == rm* ]] && pre_rm="rm \"$target\" &&"
			if [[ -n "$do_install" ]]; then
				echo ": $(g_colr MAGENTA Symlinking $src) from $target to $ln_to"
				eval $pre_rm              ln -s "$ln_to" "$target" || exit 4
			else
				echo "$pre_rm${pre_rm:+ }"ln -s "$ln_to" "$target"
			fi
			do_cp=
		fi
	elif [[ -n $lines ]]; then
		if [[ ! -e "$target" ]]; then
			echo ": Info: No file $target for appending dotlines line - will copy"
			do_cp=cp
		elif [[ -L "$target" ]]; then
			echo ": $(g_colr YELLOW Warning: Symlink target) $target $(g_colr BLACK from $src)"
		else
			local xref=$(grep -o xref_'[^ ]*' < "$src" | sort -u)
			if [[ -z "$xref" ]]; then
				echo ": $(g_colr RED Error: No xref) $src"
				exit 44
			fi
			local xref_src=$(perl -nsE 'print if /$x/.../$x/' -- -x="$xref" < "$src")
			if [[ -z "$xref_src" ]]; then
				echo ": $(g_colr RED Error: Bad xref) $src"
				exit 22
			fi
			src_up_ensure_diff
			echo ": Info: Checking $(g_colr cyan $target) for dotlines lines with $(g_colr BLACK $xref)"
			res=0; $src_up_DIFF -u --label "$target"	<(perl -nsE 'print if /$x/.../$x/' -- -x="$xref" < "$target") \
					--label "$src"		<(echo "$xref_src") || res=$?
			if [[ $res == 1 ]]; then
				# there is a diff
				if [[ -n "$do_install" ]]; then
					echo ": $(g_colr CYAN DIFF $src) Copying to $target"
					local target_noo=${TMPDIR-/tmp}/sh_init_tgt.noo.$$
					{
						perl -nsE 'print unless /$x/.../$x/' -- -x="$xref" < "$target"
						cat "$src"
					} > "$target_noo"
					res=0; $src_up_DIFF -u "$target" --label tmp-chunk "$target_noo"	|| res=$?
					if [[ $res == 1 ]]; then
						if ! cat "$target_noo" >| "$target"; then
							rm "$target_noo"
							exit 55
						fi
						rm "$target_noo"
					else
						echo ": $(g_colr RED DIFF res=$res $src) for $target"
						rm "$target_noo"
						exit 77
					fi
				else
					echo ": $(g_colr CYAN DIFF $src) $target"
				fi
			elif [[ $res != 0 ]]; then
				echo ": $(g_colr RED Error: Bad diff) $src"
				exit $res
			fi
		fi
	else
		if [[ ! -e "$target" ]]; then
			echo ": INFO No file $target"
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
			echo ": $(g_colr MAGENTA Copying $src) to $target $(g_colr BLACK "(mode: $mode)")"
			yorn		$this_install	-m \"$mode\" \"$src\" \"$target\" && \
				{ eval	$this_install	-m \"$mode\" \"$src\" \"$target\" || exit 4; }
			[[ -z "$verbose" ]] || echo ": $(ls -l "$target")"
		else
			echo ":"	"$this_install	-m \"$mode\" \"$src\" \"$target\"" || exit 4
		fi
	fi
}
