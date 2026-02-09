_ldattach_module()
{
	local cur prev OPTS
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"
	case $prev in
		'-s'|'--speed')
			COMPREPLY=( $(compgen -W "speed" -- $cur) )
			return 0
			;;
		'-c'|'--intro-command')
			COMPREPLY=( $(compgen -W "string" -- $cur) )
			return 0
			;;
		'-p'|'--pause')
			COMPREPLY=( $(compgen -W "seconds" -- $cur) )
			return 0
			;;
		'-i'|'--iflag')
			local IFLAGS
			IFLAGS="BRKINT ICRNL IGNBRK IGNCR IGNPAR IMAXBEL
				INLCR INPCK ISTRIP IUCLC IUTF8 IXANY
				IXOFF IXON PARMRK
				-BRKINT -ICRNL -IGNBRK -IGNCR -IGNPAR -IMAXBEL
				-INLCR -INPCK -ISTRIP -IUCLC -IUTF8 -IXANY
				-IXOFF -IXON -PARMRK"
			COMPREPLY=( $(compgen -W "$IFLAGS" -- $cur) )
			return 0
			;;
		'-h'|'--help'|'-V'|'--version')
			return 0
			;;
	esac
	case $cur in
		-*)
			OPTS="--debug
				--speed
				--intro-command
				--pause
				--sevenbits
				--eightbits
				--noparity
				--evenparity
				--oddparity
				--onestopbit
				--twostopbits
				--iflag
				--help
				--version"
			COMPREPLY=( $(compgen -W "${OPTS[*]}" -- $cur) )
			return 0
			;;
		/*)
			local IFS=$'\n'
			compopt -o filenames
			COMPREPLY=( $(compgen -f -- $cur) )
			return 0
			;;
	esac
	local LDISC_DEVICE
	LDISC_DEVICE="6PACK AX25 GIGASET GIGASET_M101 HCI HDLC IRDA M101
			MOUSE PPP PPS R3964 SLIP STRIP SYNCPPP SYNC_PPP
			TTY X25 /dev/"
	COMPREPLY=( $(compgen -W "$LDISC_DEVICE" -- $cur) )
	return 0
}
complete -F _ldattach_module ldattach
