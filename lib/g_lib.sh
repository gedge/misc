#!/bin/false dotme

# version: 1.0.20241126
# for licence/copyright, see: https://github.com/gedge/misc

# configure options with the command:
#       g_opts <opts>...
# <opts> can be:
#       colr        force use of colour in logging
#       host        use $myHOST or hostname in logging (see 'nohost')
#       info        show "INFO" prefix when using g_info
#       nohost      do not use hostname in logging (see 'host')

# global vars:
#   g_colr_cache       - cache of colours
#   g_colr_force       - if set, will force colour output
#   g_do_all           - if set, responds positively to any yorn (see `yorn --reset-all`)
#   g_info_info        - used internally (when `g_opts info` used, g_info shows "INFO")
#   g_lib_loaded       - has this file been loaded
#   g_lib_nonfatal     - do not exit when g_die is used (return failure)
#   g_ts_host          - used internally (when `g_opts nohost` not used)
#
#   g_reader           - set by `g_reader`
#   g_select           - set by `g_select`
#   yorn               - set by `yorn`

if [[ -z ${g_lib_loaded:-} ]]; then
g_lib_loaded=1
g_ts_host=${myHOST:-}
g_info_info=
g_colr_force=
typeset -A g_colr_cache=()

g_colr() { local col=$1 recurse= rst=$'\e[0m'; shift  # '[-r] bright_white_on_red' WHITE_on_red bold -- all valid
	if [[ $col == -r ]]; then recurse=1; col=$1; shift; fi
	if [[ -n $g_colr_force || -t 0 ]]; then
		if [[ -z ${g_colr_cache[$col]-} ]]; then
			local col_code=$'\e['$(perl -E '%c=(bold=>1,black=>30,red=>31,green=>32,yellow=>33,blue=>34,magenta=>35,cyan=>36,white=>37,reset=>0); $bg=0; @c=(0);
					for (split "_on_", shift @ARGV) { $c=$bg; $c+=60 if /^[A-Z]/ and $_=lc $_ or $_ =~ s/^bright_//; push @c, (defined $c{$_} ? $c+$c{$_} : $c+$_); $bg+=10; }
					say join(";", @c)' $col)m
			g_colr_cache+=( [$col]="$col_code" )
		fi
		col=${g_colr_cache[$col]}
		if [[ -n $recurse ]]; then set -- "${@//$rst/$col}"; fi
		if [[ -n ${MAKELEVEL:-} ]] && (( MAKELEVEL > 0 )); then echo "$col""$@""$rst"; else echo -e "$col""$@""$rst"; fi
	else
		echo "$@"
	fi
}
g_ts()      { echo  $(g_colr    BLUE   $(date '+%F %T')) ${g_ts_host:+$(g_colr green $g_ts_host)} "$@"; }
g_info()    { g_ts "${g_info_info}$(g_colr -r cyan "$@")"; }
g_trace()   { g_ts "$(g_colr -r blue   TRACE) $(g_colr -r BLACK "$@")" >&2; }
g_err()     { g_ts "$(g_colr -r RED    ERROR "$@")" >&2; }
g_warn()    { g_ts "$(g_colr -r YELLOW WARN  "$@")" >&2; }
g_log()     { g_ts "$@"; }
g_opts()    { local res=0; while [[ -n ${1:-} ]]; do
	if   [[ $1 ==   host ]]; then g_ts_host=${myHOST:-$(hostname -s)}
	elif [[ $1 == nohost ]]; then g_ts_host=
	elif [[ $1 ==   colr ]]; then g_colr_force=1
	elif [[ $1 ==   info ]]; then g_info_info="$(g_colr CYAN "INFO ")"
	else g_die 2 Bad g_opts: $1 || res=$?
	fi; shift
	done; return $res
}
g_zsh()     { [[ -n ${ZSH_NAME:-} ]]; }
g_row_col() { local X= R= C=; if g_zsh; then IFS=';[' read -sdR X\?$'\E[6n' R C; else IFS=';[' read -sdR -p $'\E[6n' X R C; fi; echo $R $C; }
g_col()     { local row_col="$(g_row_col)"; row_col=${row_col#* }; echo ${row_col:-0}; }
g_cont()    { local res=$1 arg=--no res_txt=; shift; if [[ $res == -y ]]; then arg=; res=$1; shift; fi; if [[ $res != 0 ]]; then res_txt=" after $(g_colr bright_white_on_red error code $res)"; else arg=; fi; yorn --ignore-all $arg "$@" "Continue$res_txt" || g_exit $res; }

g_exit() {
	local res=$1; shift
	[[ -n ${g_lib_nonfatal:-} ]] && return $res
	exit $res
}
g_die() {
	local res=$1; shift
	g_err "$@"
	g_exit $res
}

g_ensure_env()  { local e= res=0;for e; do if g_zsh; then [[ -n ${(P)e} ]] && continue; else [[ -n ${!e} ]] && continue; fi; g_die 2 $e unset || res=$?; done; return $res; }
g_ensure_hash() { local e= res=0;for e; do eval [[ -n \${$e[@]} ]] || g_die 2 $e unset || res=$?; done; return $res; }
g_ensure_dir()  { local d= res=0;for d; do [[ -d $d             ]] || mkdir -p $d || g_die 2 $d failed || res=$?; done; return $res; }
g_ensure_in_path() { # [ --end ] path...
	local end_ok= p=
	while true; do
		case $1 in
			(--end)	end_ok=1;	;;
			(*)	break;		;;
		esac
		shift
	done
	for p; do
		[[ :$PATH: == *:$p:* ]] && continue
		if [[ -n $end_ok ]]; then PATH=$PATH:$p; continue; fi
		PATH=$p:$PATH
	done
}

g_yorn_prompt() {
	local prompt=$1 res=0; shift
	if g_zsh; then IFS= read "$@" yorn\?"$prompt "      || res=$?
	else           IFS= read "$@" -p    "$prompt " yorn || res=$?
	fi
	(( $(g_col) <= 1 )) || echo
	return $res
}

g_do_all=
yorn() {
	local quit_to= def=yn def_colr=cyan not_def_colr=bright_blue g_all=a do_it= res= cont= comment= pre_comment= cont_ok= no_ok= any_key= hit= opts=
	local ignore_all= cd_in= timeout= timeout_arg= timeout_txt= timeout_yorn=n help=h quit=q quit_soft= quit_res=0 str= str_def= key1_flag=-k key1=1 twice=
	while [[ -n ${1-} && $1 == --* ]]; do
		if   [[ $1 == --           ]]; then shift; break
		elif [[ $1 == --any        ]]; then any_key=y
		elif [[ $1 == --comment    ]]; then comment=$(g_colr -r yellow "$2 "); shift
		elif [[ $1 == --cont       ]]; then cont=y
		elif [[ $1 == --no         ]]; then def=ny; def_colr=bright_yellow
		elif [[ $1 == --no-ok      ]]; then no_ok=1
		elif [[ $1 == --opts       ]]; then def="$2"; opts=1; shift
		elif [[ $1 == --ignore-all ]]; then ignore_all=1
		elif [[ $1 == --in         ]]; then cd_in=$2; shift; pre_comment="(in $(g_colr bright_cyan $cd_in)) "
		elif [[ $1 == --x          ]]; then do_it=1
		elif [[ $1 == --xc         ]]; then do_it=1; cont=y
		elif [[ $1 == --xc-ok      ]]; then do_it=1; cont=y; cont_ok=$2; shift
		elif [[ $1 == --no-all     ]]; then g_all=
		elif [[ $1 == --no-help    ]]; then help=
		elif [[ $1 == --no-quit    ]]; then quit=
		elif [[ $1 == --soft-quit  ]]; then quit_soft=1
		elif [[ $1 == --do-all     ]]; then g_do_all=1; [[ -z $2 ]] && return
		elif [[ $1 == --reset-all  ]]; then g_do_all=;  [[ -z $2 ]] && return
		elif [[ $1 == --twice      ]]; then twice=1
		elif [[ $1 == --str        ]]; then str=1; str_def=$2; key1=; key1_flag=; shift # default for (blank) input string
								#	else allow `string<Enter>`; ' ' triggers blank returned ($yorn)
		elif [[ $1 == --quit-res   ]]; then quit_res=$2; shift
		elif [[ $1 == --quit-to    ]]; then quit_to=$2; shift
		elif [[ $1 == --timeout    ]]; then timeout=$2; shift
		elif [[ $1 == --timeout-ok ]]; then timeout=$2; timeout_yorn=y; shift
		else break
		fi
		shift
	done
	[[ -n $key1_flag ]] && ! g_zsh && key1_flag=-n
	if [[ -n $timeout ]]; then timeout_arg=-t; timeout_txt="$(g_colr yellow " ${timeout}s")"; fi
	if [[ -n $g_do_all && -z $ignore_all && -z $str ]]; then
		if [[ ${def:0:1} == n ]]; then
			res=1	# skip --no when 'all'
			g_info			"$(g_colr yellow SKIP): $pre_comment$comment$(g_colr yellow "$@")"
		else
			res=0
			if [[ -n $do_it ]]; then	g_info EXEC: "$pre_comment$comment"$(g_colr bright_white "$@")
			else				g_info ALL:  "$pre_comment$comment"$(g_colr bright_white "$@")
			fi
		fi
	fi
	if [[ -z $str ]]; then
		hit="$(g_colr -r $not_def_colr "$(g_colr $def_colr ${def:0:1})${def:1}${g_all}${help}${quit}")"
	else
		hit="def: "$(g_colr -r $not_def_colr "$str_def")
		timeout_yorn=$str_def
	fi
	[[ -n $any_key ]] && hit="$(g_colr -r $not_def_colr hit any key or: $(g_colr cyan hq))"
	while [[ -z $res ]]; do
		if ! g_yorn_prompt "$(g_info "$pre_comment$comment""$@") [$hit]$timeout_txt${str:+ ?}" $timeout_arg $timeout $key1_flag $key1; then
			[[ -n $timeout ]] && yorn=$timeout_yorn
		fi
		if [[ -n $str ]]; then
			if   [[ $yorn == " " ]]; then yorn=
			elif [[ -z $yorn     ]]; then yorn=$str_def
			fi
			return
		fi
		[[ -n $any_key && :${help}:${quit}: != *:$yorn:* ]] && return 0
		if [[ -n $yorn && $yorn == $'\f' ]]; then clear; continue; fi
		if [[ -n $yorn && $yorn == $'\e' ]]; then g_warn huh; continue; fi
		if [[ -z $yorn || $yorn == " " || $yorn == $'\n' ]]; then yorn=${def:0:1}; fi
		if   [[ -n $quit  && $yorn == $quit  ]]; then [[ -n $quit_soft ]] && return 1; if [[ -n $quit_to ]]; then $quit_to; fi; g_exit $quit_res; return $?
		elif [[ -n $g_all && $yorn == $g_all ]]; then g_do_all=yes; res=0
		elif [[ -n $help  && $yorn == $help  ]]; then g_info "Hit: $(g_colr bright_magenta y)=yes, $(g_colr bright_magenta n)=no, $(g_colr bright_magenta a)=all (accept default for all subsequent), $(g_colr bright_magenta q)=quit"
		elif [[ -n $opts                     ]]; then if [[ $def == *"$yorn"* ]]; then res=0; fi
		elif [[ $yorn == n                   ]]; then res=1; if [[ -n $no_ok ]]; then do_it=; res=0; fi
		elif [[ $yorn == y                   ]]; then res=0
		fi
		if [[ -n $res && $res == 0 && -n $twice ]]; then
			local save_yorn=$yorn
			g_yorn_prompt "$(g_info "$(g_colr -r yellow "Hit '$(g_colr -r bright_yellow c)' to confirm:")" "$pre_comment$comment""$@") [$(g_colr $def_colr n)$(g_colr $not_def_colr c${quit})]" $key1_flag $key1
			if [[ $yorn != c ]]; then res=; fi
			yorn=$save_yorn
		fi
	done
	if [[ -n $do_it && $res == 0 ]]; then
		if [[ -n $cd_in ]]; then cd $cd_in || res=$?; fi
		if (( res == 0 )); then "$@" || res=$?; fi
		if (( res > 0 )); then
			if [[ -n $cont ]]; then
				if [[ $cont_ok == $res ]]; then g_cont -y $res || return $?; else g_cont $res || return $?; fi
			fi
		fi
	fi
	return $res
}

g_reader() {
	local def=
	while [[ -n $1 && $1 == --* ]]; do
		if   [[ $1 == --           ]]; then shift; break
		elif [[ $1 == --def        ]]; then def=$2; shift
		else break
		fi
		shift
	done
	yorn --str "$def" "$@"
	g_reader=$yorn
}

g_select() {
	local def= loop= a= quit_opt=--no-quit prompt=Select values= none_opt= none_val= extra_ch=. x_all=
	local opt_keys=1234567890abcdefghijklmnoprstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ
	typeset -A key_to_val=()
	while [[ -n $1 && $1 == --* ]]; do
		if   [[ $1 == --          ]]; then shift; break
		elif [[ $1 == --def       ]]; then def=$2; shift
		elif [[ $1 == --loop      ]]; then quit_opt=--soft-quit; loop=1
		elif [[ $1 == --prompt    ]]; then prompt=$2; shift
		elif [[ $1 == --none-opt  ]]; then none_opt=$2; none_val=$3; shift 2
							opt_keys=${opt_keys/$none_opt}
							key_to_val+=( [$none_opt]=$none_val [$extra_ch$none_opt]=$none_val )
		elif [[ $1 == --quit-ok   ]]; then quit_opt=
		elif [[ $1 == --quit-soft ]]; then quit_opt=--soft-quit
		elif [[ $1 == --values    ]]; then values=1
		elif [[ $1 == --xx        ]]; then x_all=1
		else break
		fi
		shift
	done
	# iter_num: 1==(prune --key from opt_keys) 2==(build all_opts, show opts) 3...==prompt
	local iter_num all_opts= do_opts=: extra_opts=
	for (( iter_num=1 ; ; iter_num++ )); do
		local opt_num=1
		local opt_col=bright_cyan next_opt_key= opt_do=$x_all opt_comment=
		for (( a=1; a <= $#; a++ )); do
			local arg=${@:$a:1}
			if   [[ $arg == --x           ]]; then opt_do=1; opt_col=bright_yellow
			elif [[ $arg == --comment     ]]; then let a++; opt_comment="${@:$a:1} "
			elif [[ $arg == --key         ]]; then
				let a++
				next_opt_key=${@:$a:1}
				(( iter_num == 1 )) && opt_keys=${opt_keys/$next_opt_key}
			else
				local opt=$next_opt_key
				next_opt_key=
				if [[ -z $opt ]]; then
					if (( opt_num > ${#opt_keys} )); then
						opt=$extra_ch${opt_keys:(( opt_num - ${#opt_keys} - 1 )):1}
						if (( iter_num == 2 )); then
							extra_opts=$extra_opts${opt:1}
						fi
					else
						opt=${opt_keys:(( opt_num - 1 )):1}
					fi
					let opt_num++
				fi
				if (( iter_num > 1 )); then
					if (( iter_num == 2 )); then
						key_to_val+=( ["$opt"]=$arg )
						if [[ $opt == $extra_ch* ]]; then
							[[ ${all_opts:((${#all_opts}-1))} != $extra_ch ]] && all_opts=${all_opts}$extra_ch
						else
							all_opts=${all_opts}$opt
						fi
						[[ -n $opt_do && $opt != $none_opt ]] && do_opts=${do_opts}$opt:
					fi
					g_info " $(g_colr bright_yellow $opt)  ${opt_comment}$(g_colr $opt_col "$arg")"
				fi

				# reset per-opt vars
				opt_comment=
				opt_col=bright_cyan
				opt_do=$x_all
			fi
		done

		(( iter_num == 1 )) && continue

		if [[ -n $none_opt ]]; then
			g_info " $(g_colr bright_yellow $none_opt)  ${opt_comment}$(g_colr $opt_col "$none_val")"
			if [[ $def == $none_opt ]]; then
				all_opts=$none_opt${all_opts}
			else
				all_opts=${all_opts}$none_opt
			fi
		fi

		extra_yorn=
		yorn --no-help --no-all $quit_opt --opts "$all_opts" "$prompt"
		if [[ -n $extra_opts && $yorn == $extra_ch ]]; then
			extra_yorn=$yorn
			yorn --no-help --no-all $quit_opt --opts "$extra_opts$none_opt" "[post-$extra_ch] $prompt"
		fi
		g_select=$extra_yorn$yorn
		[[ -n $values ]] && g_select=${key_to_val[$extra_yorn$yorn]}

		[[ $quit_opt == --soft-quit && $yorn == q ]] && return 1
		[[ $do_opts == *:$extra_yorn$yorn:* ]] && eval "${key_to_val[$extra_yorn$yorn]}"

		[[ -z $loop ]] && return
	done
}

fi  # g_lib_loaded
