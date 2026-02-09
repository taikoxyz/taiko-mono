_setterm_module()
{
	local bright cur prev OPTS
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"
	case $prev in
		'--term')
			local TERM_LIST I
			TERM_LIST=''
			for I in /usr/share/terminfo/?/*; do
				TERM_LIST+="${I##*/} "
			done
			COMPREPLY=( $(compgen -W "$TERM_LIST" -- $cur) )
			return 0
			;;
		'--foreground'|'--background')
			COMPREPLY=( $(compgen -W "black blue cyan default green magenta red white yellow" -- $cur) )
			return 0
			;;
		'--ulcolor'|'--hbcolor'|'bright')
			if [ $prev != 'bright' ]; then
				bright='bright black grey'
			else
				bright=''
			fi
			COMPREPLY=( $(compgen -W "$bright blue cyan green magenta red white yellow" -- $cur) )
			return 0
			;;
		'--cursor'|'--repeat'|'--appcursorkeys'|'--linewrap'|'--inversescreen'|'--bold'|'--half-bright'|'--blink'|'--reverse'|'--underline'|'--msg')
			COMPREPLY=( $(compgen -W "off on" -- $cur) )
			return 0
			;;
		'--clear')
			COMPREPLY=( $(compgen -W "all rest" -- $cur) )
			return 0
			;;
		'--tabs'|'--clrtabs')
			COMPREPLY=( $(compgen -W "tab1 tab2 tab3 tab160" -- $cur) )
			return 0
			;;
		'--regtabs')
			COMPREPLY=( $(compgen -W "{1..160}" -- $cur) )
			return 0
			;;
		'--blank')
			COMPREPLY=( $(compgen -W "{0..60} force poke" -- $cur) )
			return 0
			;;
		'--dump'|'--append')
			local NUM_CONS
			NUM_CONS=(/dev/vcsa?*)
			COMPREPLY=( $(compgen -W "{1..${#NUM_CONS[*]}}" -- $cur) )
			return 0
			;;
		'--file')
			local IFS=$'\n'
			compopt -o filenames
			COMPREPLY=( $(compgen -f -- $cur) )
			return 0
			;;
		'--msglevel')
			COMPREPLY=( $(compgen -W "{0..8}" -- $cur) )
			return 0
			;;
		'--powersave')
			COMPREPLY=( $(compgen -W "on vsync hsync powerdown off" -- $cur) )
			return 0
			;;
		'--powerdown')
			COMPREPLY=( $(compgen -W "{0..60}" -- $cur) )
			return 0
			;;
		'--blength')
			COMPREPLY=( $(compgen -W "0-2000" -- $cur) )
			return 0
			;;
		'--bfreq')
			COMPREPLY=( $(compgen -W "freqnumber" -- $cur) )
			return 0
			;;
		'--help'|'--version')
			return 0
			;;
	esac
	OPTS="	--term
		--reset
		--resize
		--initialize
		--cursor
		--repeat
		--appcursorkeys
		--linewrap
		--default
		--foreground
		--background
		--ulcolor
		--hbcolor
		--ulcolor
		--hbcolor
		--inversescreen
		--bold
		--half-bright
		--blink
		--reverse
		--underline
		--store
		--clear
		--tabs
		--clrtabs
		--regtabs
		--blank
		--dump
		--append
		--file
		--msg
		--msglevel
		--powersave
		--powerdown
		--blength
		--bfreq
		--version
		--help"
	COMPREPLY=( $(compgen -W "${OPTS[*]}" -- $cur) )
	return 0
}
complete -F _setterm_module setterm
