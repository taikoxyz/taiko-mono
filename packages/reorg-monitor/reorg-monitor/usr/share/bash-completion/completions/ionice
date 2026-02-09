_ionice_module()
{
	local cur prev OPTS
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"
	case $prev in
		'-c'|'--class')
			COMPREPLY=( $(compgen -W "{0..3} none realtime best-effort idle" -- $cur) )
			return 0
			;;
		'-n'|'--classdata')
			COMPREPLY=( $(compgen -W "{0..7}" -- $cur) )
			return 0
			;;
		'-P'|'--pgid')
			local PGID
			PGID="$(awk '{print $5}' /proc/*/stat 2>/dev/null | sort -u)"
			COMPREPLY=( $(compgen -W "$PGID" -- $cur) )
			return 0
			;;
		'-p'|'--pid')
			local PIDS
			PIDS=$(for I in /proc/[0-9]*; do echo ${I##"/proc/"}; done)
			COMPREPLY=( $(compgen -W "$PIDS" -- $cur) )
			return 0
			;;
		'-u'|'--uid')
			local UIDS
			UIDS="$(stat --format='%u' /proc/[0-9]* | sort -u)"
			COMPREPLY=( $(compgen -W "$UIDS" -- $cur) )
			return 0
			;;
		'-h'|'--help'|'-V'|'--version')
			return 0
			;;
	esac
	case $cur in
		-*)
			OPTS="--class --classdata --pid --pgid --ignore --uid --version --help"
			COMPREPLY=( $(compgen -W "${OPTS[*]}" -- $cur) )
			return 0
			;;
	esac
	local IFS=$'\n'
	compopt -o filenames
	COMPREPLY=( $(compgen -f -- $cur) )
	return 0
}
complete -F _ionice_module ionice
