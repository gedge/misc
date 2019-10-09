#!/bin/false dotme

# for licence/copyright, see: https://github.com/gedge/misc

if [[ -z ${g_lib_loaded:-} ]]; then
g_lib_loaded=1

g_colr() { local col=$1 recurse= rst=$'\e[0m'; shift  # '[-r] bright_white_on_red' WHITE_on_red bold -- all valid
    if [[ $col == -r ]]; then recurse=1; col=$1; shift; fi
    if [[ -t 0 ]]; then
        col=$'\e['$(perl -E '$_="0;";$c=shift @ARGV;%c=(bold=>1,black=>30,red=>31,green=>32,yellow=>33,blue=>34,magenta=>35,cyan=>36,white=>37,reset=>0);$_="1;" if $c =~ /^[A-Z]/ and $c=lc $c or $c =~ s/^bright_//;$_.=10+$c{$1}.";" if $c =~ s/_on_(\w+)$// and defined $c{$1};if(defined $c{$c}){$_.=$c{$c}}else{$_=$c}say' $col)m
        if [[ -n $recurse ]]; then set -- "${@//$rst/$col}"; fi
        echo -e "$col""$@""$rst"
    else
        echo "$@"
    fi
}
g_ts()      { echo  $(g_colr    BLUE   $(date '+%F %T')) ${g_ts_host:+$(g_colr green $g_ts_host)} "$@"; }
g_info()    { g_ts "$(g_colr -r cyan   "$@")"; }
g_trace()   { g_info "$@" >&2; }
g_info2()   { g_info "$@" >&2; } # DEPRECATED
g_err()     { g_ts "$(g_colr -r RED    ERROR "$@")" >&2; }
g_warn()    { g_ts "$(g_colr -r YELLOW WARN  "$@")" >&2; }
g_log()     { g_ts "$@"; }
g_opts()    { while [[ -n $1 ]]; do if [[ $1 == host ]]; then g_ts_host=$myHOST; fi; shift; done; }
g_zsh()     { [[ -n ${ZSH_NAME:-} ]]; }
g_row_col() { local X= R= C=; if g_zsh; then IFS=';[' read -sdR X\?$'\E[6n' R C; else IFS=';[' read -sdR -p $'\E[6n' X R C; fi; echo $R $C; }
g_col()     { local rc="$(g_row_col)"; echo ${rc#* }; }
g_cont()    { local res=$1 arg=--no res_txt=; shift; if [[ $res == -y ]]; then arg=; res=$1; shift; fi; if [[ $res != 0 ]]; then res_txt=" after $(g_colr bright_white_on_red error code $res)"; else arg=; fi; yorn --ignore-all $arg "$@" "Continue$res_txt" || exit $res; }

g_die() {
    local res=$1; shift
    g_err "$@"
    exit $res
}

g_ensure_env() { local e=;for e; do [[ -z ${!e} ]] && g_die 2 $e unset; done; }
g_ensure_dir() { local d=;for d; do [[ -d $d ]] || mkdir -p $d || g_die 2 $d failed; done; }
g_ensure_in_path() { # [ --end ] path...
	local end_ok= p=
	while true; do
            case $1 in
                --end) end_ok=1; ;;
                *) break; ;;
            esac
            shift
        done
	for p; do
		[[ :$PATH: == *:$p:* ]] && continue
		if [[ -n $end_ok ]]; then PATH=$PATH:$p; continue; fi
		PATH=$p:$PATH
	done
}

g_do_all=
yorn() {
	local quit_to= def=yn def_colr=cyan g_all=a do_it= res= cont= comment= pre_comment= cont_ok= no_ok= any_key= hit=
	local ignore_all= cd_in= timeout= timeout_arg= timeout_txt= timeout_yorn=n quit=q str= str_def= key1=1
	while [[ -n $1 && $1 == --* ]]; do
		if   [[ $1 == --           ]]; then shift; break
		elif [[ $1 == --any        ]]; then any_key=y
		elif [[ $1 == --comment    ]]; then comment=$(g_colr -r yellow "$2 "); shift
		elif [[ $1 == --cont       ]]; then cont=y
		elif [[ $1 == --no         ]]; then def=ny; def_colr=bright_yellow
		elif [[ $1 == --no-ok      ]]; then no_ok=1
		elif [[ $1 == --ignore-all ]]; then ignore_all=1
		elif [[ $1 == --in         ]]; then cd_in=$2; shift; pre_comment="(in $(g_colr bright_cyan $cd_in)) "
		elif [[ $1 == --x          ]]; then do_it=1
		elif [[ $1 == --xc         ]]; then do_it=1; cont=y
		elif [[ $1 == --xc-ok      ]]; then do_it=1; cont=y; cont_ok=$2; shift
		elif [[ $1 == --no-all     ]]; then g_all=
		elif [[ $1 == --no-quit    ]]; then quit=
		elif [[ $1 == --do-all     ]]; then g_do_all=1; [[ -z $2 ]] && return
		elif [[ $1 == --reset-all  ]]; then g_do_all=;  [[ -z $2 ]] && return
		elif [[ $1 == --str        ]]; then str=1; str_def=$2; key1=; shift  # default for (blank) input string, else allow `string<Enter>`; ' ' triggers blank returned ($yorn)
		elif [[ $1 == --quit-to    ]]; then quit_to=$2; shift
		elif [[ $1 == --timeout    ]]; then timeout=$2; shift
		elif [[ $1 == --timeout-ok ]]; then timeout=$2; timeout_yorn=y; shift
		else break
		fi
		shift
	done
	if [[ -n $timeout ]]; then timeout_arg=-t; timeout_txt="$(g_colr yellow " ${timeout}s")"; fi
	if [[ -n $g_do_all && -z $ignore_all && -z $str ]]; then
		if [[ ${def:0:1} == n ]]; then
			res=1	# skip --no when 'all'
			g_info SKIP:  "$pre_comment$comment"$(g_colr bright_white "$@")
		else
			res=0
			if [[ -n $do_it ]]; then	g_info EXEC: "$pre_comment$comment"$(g_colr bright_white "$@")
			else				g_info ALL:  "$pre_comment$comment"$(g_colr bright_white "$@")
			fi
		fi
	fi
	while [[ -z $res ]]; do
		if [[ -z $str ]]; then
			hit="$(g_colr -r bright_blue "$(g_colr $def_colr ${def:0:1})${def:1}${g_all}h${quit}")"
		else
			hit="def: "$(g_colr -r bright_blue "$str_def")
			timeout_yorn=$str_def
		fi
		[[ -n $any_key ]] && hit="$(g_colr -r bright_blue hit any key or: $(g_colr cyan hq))"
		if g_zsh; then IFS= read $timeout_arg $timeout ${key1:+-k} $key1 yorn\?"$(g_info "$pre_comment$comment""$@") [$hit]$timeout_txt${str:+ ?} "
		else           IFS= read $timeout_arg $timeout ${key1:+-n} $key1 -p    "$(g_info "$pre_comment$comment""$@") [$hit]$timeout_txt${str:+ ?} " yorn
		fi
		if [[ -n $timeout && $? -ne 0 ]]; then yorn=$timeout_yorn; fi
		if [[ -n $str ]]; then
			if   [[ $yorn == " " ]]; then yorn=
			elif [[ -z $yorn     ]]; then yorn=$str_def
			fi
			return
		fi
		(( $(g_col) > 1 )) && echo
		[[ -n $any_key && :h:q: != *:$yorn:* ]] && return 0
		if [[ -z $yorn || $yorn == " " || $yorn == $'\n' ]]; then yorn=${def:0:1}; fi
		if   [[ -n $quit  && $yorn == q      ]]; then [[ -z $quit_to ]] && exit 0; $quit_to; exit 0
		elif [[ -n $g_all && $yorn == $g_all ]]; then g_do_all=yes; res=0
		elif [[ $yorn == h                   ]]; then g_info "Hit: $(g_colr bright_magenta y)=yes, $(g_colr bright_magenta n)=no, $(g_colr bright_magenta a)=all (accept default for all subsequent), $(g_colr bright_magenta q)=quit"
		elif [[ $yorn == n                   ]]; then res=1; if [[ -n $no_ok ]]; then do_it=; res=0; fi
		elif [[ $yorn == y                   ]]; then res=0
		fi
	done
	if [[ -n $do_it && $res == 0 ]]; then
		if [[ -n $cd_in ]]; then cd $cd_in || res=$?; fi
		if (( res == 0 )); then "$@" || res=$?; fi
		if (( res > 0 )); then
			if [[ -n $cont ]]; then
				if [[ $cont_ok == $res ]]; then g_cont -y $res; else g_cont $res; fi
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

fi
