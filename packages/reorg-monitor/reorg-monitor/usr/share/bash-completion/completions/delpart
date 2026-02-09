_delpart_module()
{
	local cur prev OPTS
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"
	case $prev in
		'-h'|'--help'|'-V'|'--version')
			return 0
			;;
	esac
	case $COMP_CWORD in
		1)
			OPTS="--help --version $(lsblk -pnro name)"
			compopt -o bashdefault -o default
			COMPREPLY=( $(compgen -W "${OPTS[*]}" -- $cur) )
			;;
		2)
			prev="${COMP_WORDS[COMP_CWORD-1]}"
			COMPREPLY=( $(compgen -W "$(cat /sys/block/${prev##*/}/*/partition 2>/dev/null)" -- $cur) )
			;;
	esac
	return 0
}
complete -F _delpart_module delpart
