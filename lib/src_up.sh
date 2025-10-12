#!/bin/false dotme

# version: 1.0.20250730
# for licence/copyright, see: https://github.com/gedge/misc

if [[ -f lib/g_lib.sh && -f lib/src_up.sh && -d .git ]]; then
	# use local version when developing
	. lib/g_lib.sh
else
	. g_lib.sh
fi

case "$(uname -s)" in
	(Linux)
		STAT="stat -c '%a'"
		GROUP=root
		;;
	(*)
		STAT="stat -f '%Mp%Lp'"
		GROUP=wheel
		;;
esac

DIFF=${DIFF:-colordiff}
INSTALL=${INSTALL:-install -p}
ROOT_INSTALL="$INSTALL -o '$USER' -g '$GROUP'"

# do_diff returns 1 when diff returns 1 (the files differ)
function do_diff() {
	local src=$1 target=$2 verbose=$3
	local res=0; $DIFF -q "$target" "$src" > /dev/null || res=$?
	if [[ $res == 1 ]]; then
		if [[ "$target" -nt "$src" ]]; then
			$DIFF -u "$src" "$target"
			echo ": $(g_colr RED WARNING: target newer), pull: cp -ip \"$target\" \"$src\""
			echo ": $(g_colr YELLOW "    or:  force older"), push: cp -ip \"$src\" \"$target\""
			res=2
		else
			$DIFF -u "$target" "$src"
		fi
	elif [[ $res -ne 0 ]]; then
		echo : $(g_colr RED Error: Bad diff) -u $target $src
		exit $res
	else
		[[ -n "$verbose" ]] && echo : INFO No diff -u $target $src
	fi
	return $res
}

# src_up { --0755 | --lines } { install* | diff* | ... } $src $target $verbose $ln_to
function src_up() {
	local res=0 docp= mode= lines=
	while [[ $1 == --* ]]; do
		local arg=$1; shift
		if [[ $arg =~ '^--[0-9]+$' ]]; then
			mode=${arg#--}
		elif [[ $arg == --lines ]]; then
			lines=1
		else
			echo ": $(g_colr RED Bad option:) '$arg'" >&2
			return 2
		fi
	done
	local do=$1 src=$2 target=$3 verbose=$4 ln_to=$5
	local dir=$(dirname "$target")
	if [[ $do == install* ]]; then
		if [[ ! -d "$dir" ]]; then echo : $(g_colr MAGENTA mkdir -p $dir); mkdir -p $dir || exit 1; fi
		if [[ ! -w "$dir" ]]; then g_warn "Cannot write to $dir"; fi
	fi

	if [[ -L "$src" || -n "$ln_to" ]]; then
		if [[ -z "$ln_to" ]]; then
			ln_to=$(readlink "$src")
		fi
		if [[ "$ln_to" == $dir/* ]]; then ln_to=${ln_to#$dir/}; fi
		if [[ -L "$target" ]]; then
			if [[ "$ln_to" != "$(readlink "$target")" ]]; then
				echo : $(g_colr YELLOW WARN Diff symlink) $target "→" $(readlink "$target") --- expected $ln_to
				docp=rmln
			else
				[[ -n "$verbose" ]] && echo : INFO No symlink diff $target "→" $ln_to
			fi
		elif [[ ! -e "$target" ]]; then
			echo : INFO No symlink $target
			docp=ln
		else
			echo : $(g_colr YELLOW WARN skipping existing) non-symlink: $target
			do_diff "$src" "$target" "$verbose" || res=$?
			[[ $res -eq 1 ]] && docp=cp
		fi
		if [[ -n $docp ]]; then
			pre_rm=; if [[ $docp == rm* ]] && pre_rm="rm \"$target\" &&"
			if [[ $do == install* ]]; then
				echo : $(g_colr MAGENTA Symlinking $src) from $target to $ln_to
				eval $pre_rm ln -s "$ln_to" "$target" || exit 4
			else
				echo "$pre_rm${pre_rm:+ }"ln -s "$ln_to" "$target"
			fi
			docp=
		fi
	elif [[ -n $lines ]]; then
		if [[ ! -e "$target" ]]; then
			echo : Info: No file $target for appending dotlines line - will copy
			docp=cp
		elif [[ -L "$target" ]]; then
			echo : $(g_colr YELLOW Warning: Symlink target) $target $(g_colr BLACK from $src)
		else
			xref=$(grep -o xref_'[^ ]*' < "$src" | sort -u)
			if [[ -z "$xref" ]]; then
				echo : $(g_colr RED Error: No xref) $src
				exit 44
			fi
			xref_src=$(perl -nsE 'print if /$x/.../$x/' -- -x="$xref" < "$src")
			if [[ -z "$xref_src" ]]; then
				echo : $(g_colr RED Error: Bad xref) $src
				exit 22
			fi
			echo : Info: Checking $(g_colr cyan $target) for dotlines lines with $(g_colr BLACK $xref)
			res=0; $DIFF -u --label "$target"	<(perl -nsE 'print if /$x/.../$x/' -- -x="$xref" < "$target") \
					--label "$src"		<(echo "$xref_src") || res=$?
			if [[ $res == 1 ]]; then
				if [[ $do == install* ]]; then
					echo : $(g_colr CYAN DIFF $src) Copying to $target
					target_noo=/tmp/sh_init_tgt.noo.$$
					{
						perl -nsE 'print unless /$x/.../$x/' -- -x="$xref" < "$target"
						cat "$src"
					} > "$target_noo"
					res=0; $DIFF -u "$target" --label tmp-chunk "$target_noo"	|| res=$?
					if [[ $res == 1 ]]; then
						if ! cat "$target_noo" >| "$target"; then
							rm "$target_noo"
							exit 55
						fi
						rm "$target_noo"
					else
						echo : $(g_colr RED DIFF res=$res $src) for $target
						rm "$target_noo"
						exit 77
					fi
				else
					echo : $(g_colr CYAN DIFF $src) $target
				fi
			elif [[ $res != 0 ]]; then
				echo : $(g_colr RED Error: Bad diff) $src
				exit $res
			fi
		fi
	else
		if [[ ! -e "$target" ]]; then
			echo : INFO No file $target
			docp=cp
		else
			do_diff "$src" "$target" "$verbose" || res=$?
			[[ $res -eq 1 ]] && docp=cp
		fi
	fi
	if [[ -n $docp ]]; then
		if [[ $do == install* ]]; then
			if [[ -z $mode ]]; then mode=0$(eval $STAT \"$src\"); fi
			echo : $(g_colr MAGENTA Copying $src) to $target "$(g_colr BLACK "(mode: $mode)")"
			if [[ $USER == root ]]; then
				yorn		$ROOT_INSTALL	-m \"$mode\" \"$src\" \"$target\" && \
					eval	$ROOT_INSTALL	-m \"$mode\" \"$src\" \"$target\" || exit 4
			else
				yorn		$INSTALL	-m \"$mode\" \"$src\" \"$target\" && \
					eval	$INSTALL	-m \"$mode\" \"$src\" \"$target\" || exit 4
				[[ -z "$verbose" ]] || echo ": $(ls -l "$target")"
			fi
		else
			echo ": [$do]"		$INSTALL	-m \"$mode\" \"$src\" \"$target\" || exit 4
		fi
	fi
}
