#!/bin/false dotme

if [[ -f lib/g_lib.sh ]]; then
	. lib/g_lib.sh
else
	. g_lib.sh
fi

DIFF=${DIFF:-colordiff}
src_os=$(uname -s)
if [[ $src_os == Linux ]]; then
	STAT="stat -c '%a'"
	GROUP=root
else
	STAT="stat -f '%Mp%Lp'"
	GROUP=wheel
fi
INSTALL="install -p"
ROOT_INSTALL="$INSTALL -o '$USER' -g '$GROUP'"

function do_diff() {
	local src=$1 target=$2 verbose=$3
	local res=0; $DIFF -q "$target" "$src" > /dev/null || res=$?
	if [[ $res == 1 ]]; then
		if [[ "$target" -nt "$src" ]]; then
			$DIFF -u "$src" "$target"
			echo ": $(g_colr RED WARNING: target newer), pull: cp -ip \"$target\" \"$src\""
			echo ":      or:  force older, push: cp -ip \"$src\" \"$target\""
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

# src_up [ --0755 ] { install[1] | diff[1] | ... } $src $target $verbose $ln_to
function src_up() {
	local mode=; while [[ $1 == --* ]]; do if [[ $1 =~ '^--[0-9]+$' ]]; then mode=${1#--}; shift; else echo ": $(g_colr RED Bad option '$1')"; return 2; fi; done
	local do=$1 src=$2 target=$3 verbose=$4 ln_to=$5
	local res=0 docp=

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
		fi
	else
		if [[ ! -e "$target" ]]; then
			echo : INFO No file $target
			docp=cp
		else
			do_diff "$src" "$target" "$verbose" || res=$?
			[[ $res -eq 1 ]] && docp=cp
		fi
		if [[ -n $docp ]]; then
			if [[ $do == install* ]]; then
				if [[ -z $mode ]]; then mode=0$(eval $STAT \"$src\"); fi
					echo : $(g_colr MAGENTA Copying $src) to $target "$(g_colr BLACK "(mode: $mode)")"
				if [[ $USER == root ]]; then
					eval $ROOT_INSTALL -m \"$mode\" \"$src\" \"$target\" || exit 4
				else
					eval      $INSTALL -m \"$mode\" \"$src\" \"$target\" || exit 4
					# cp -ip "$src" "$target" || exit 4
				fi
			else
				echo :	cp -ip "$src" "$target" || exit 4
			fi
		fi
	fi
}
