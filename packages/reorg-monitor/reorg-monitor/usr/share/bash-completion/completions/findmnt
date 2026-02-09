_findmnt_module()
{
	local cur prev OPTS
	COMPREPLY=()
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"
	case $prev in
		'-p'|'--poll')
			COMPREPLY=( $(compgen -W "=list" -- $cur) )
			return 0
			;;
		'-w'|'--timeout')
			COMPREPLY=( $(compgen -W "timeout" -- $cur) )
			return 0
			;;
		'-d'|'--direction')
			COMPREPLY=( $(compgen -W "forward backward" -- $cur) )
			return 0
			;;
		'-F'|'--tab-file')
			local IFS=$'\n'
			compopt -o filenames
			COMPREPLY=( $(compgen -f -- $cur) )
			return 0
			;;
		'-N'|'--task')
			local TID='' I ARR
			for I in /proc/*/mountinfo; do IFS=/ read -ra ARR <<< "$I"; TID+="${ARR[2]} "; done
			COMPREPLY=( $(compgen -W "$TID" -- $cur) )
			return 0
			;;
		'-O'|'--options')
			local MTAB_3RD I
			declare -a TMP_ARR
			declare -A MNT_OPTS
			while read MTAB_3RD; do
				IFS=',' read -ra TMP_ARR <<<"$MTAB_3RD"
				for I in ${TMP_ARR[@]}; do
					MNT_OPTS[$I]='1'
				done
			done < <($1 -rno OPTIONS)
			COMPREPLY=( $(compgen -W "${!MNT_OPTS[@]}" -- $cur) )
			return 0
			;;
		'-o'|'--output')
			local prefix realcur OUTPUT_ALL OUTPUT
			realcur="${cur##*,}"
			prefix="${cur%$realcur}"

			OUTPUT_ALL="SOURCE TARGET FSTYPE OPTIONS VFS-OPTIONS
				FS-OPTIONS LABEL UUID PARTLABEL PARTUUID
				MAJ\:MIN ACTION OLD-TARGET OLD-OPTIONS
				SIZE AVAIL USED USE% FSROOT TID ID
				OPT-FIELDS PROPAGATION FREQ PASSNO"

			for WORD in $OUTPUT_ALL; do
				if ! [[ $prefix == *"$WORD"* ]]; then
					OUTPUT="$WORD ${OUTPUT:-""}"
				fi
			done
			compopt -o nospace
			COMPREPLY=( $(compgen -P "$prefix" -W "$OUTPUT" -S ',' -- $realcur) )
			return 0
			;;
		'-t'|'--types')
			local TYPES
			TYPES="adfs affs autofs cifs coda coherent cramfs
				debugfs devpts efs ext2 ext3 ext4 hfs
				hfsplus hpfs iso9660 jfs minix msdos
				ncpfs nfs nfs4 ntfs proc qnx4 ramfs
				reiserfs romfs squashfs smbfs sysv tmpfs
				ubifs udf ufs umsdos usbfs vfat xenix xfs"
			COMPREPLY=( $(compgen -W "$TYPES" -- $cur) )
			return 0
			;;
		'-S'|'--source')
			local DEV_MPOINT
			DEV_MPOINT=$($1 -rno SOURCE | grep ^/dev)
			COMPREPLY=( $(compgen -W "$DEV_MPOINT" -- $cur) )
			return 0
			;;
		'-T'|'--target')
			local DEV_MPOINT
			DEV_MPOINT=$($1 -rno TARGET)
			COMPREPLY=( $(compgen -W "$DEV_MPOINT" -- $cur) )
			return 0
			;;
		'-M'|'--mountpoint')
			local IFS=$'\n'
			compopt -o filenames
			COMPREPLY=( $(compgen -o dirnames -- ${cur:-"/"}) )
			return 0
			;;
		'-h'|'--help'|'-V'|'--version')
			return 0
			;;
	esac
	case $cur in
		-*)
			OPTS="--fstab
				--mtab
				--kernel
				--poll
				--timeout
				--all
				--ascii
				--canonicalize
				--df
				--direction
				--evaluate
				--tab-file
				--first-only
				--invert
				--json
				--list
				--task
				--noheadings
				--notruncate
				--options
				--output
				--output-all
				--pairs
				--raw
				--types
				--nofsroot
				--submounts
				--source
				--target
				--mountpoint
				--help
				--tree
				--real
				--pseudo
				--version"
			COMPREPLY=( $(compgen -W "${OPTS[*]}" -- $cur) )
			return 0
			;;
	esac
	local DEV_MPOINT
	DEV_MPOINT=$($1 -rno TARGET,SOURCE)
	COMPREPLY=( $(compgen -W "$DEV_MPOINT" -- $cur) )
	return 0
}
complete -F _findmnt_module findmnt
