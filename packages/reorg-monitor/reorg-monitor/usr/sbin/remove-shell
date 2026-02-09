#!/bin/sh -e

if test $# -eq 0
then
        echo "usage: $0 shellname [shellname ...]" 1>&2
        exit 1
fi

file="$DPKG_ROOT/etc/shells"
# I want this to be GUARANTEED to be on the same filesystem as $file
tmpfile="${file}.tmp"
otmpfile="${file}.tmp2"

set -o noclobber

cleanup() {
	rm -f "$tmpfile" "$otmpfile"
}
trap cleanup EXIT

if ! cat "$file" > "$tmpfile"
then
        cat 1>&2 <<EOF
Either another instance of $0 is running, or it was previously interrupted.
Please examine ${tmpfile} to see if it should be moved onto ${file}.
EOF
        exit 1
fi

# this is supposed to be reliable, not pretty
for i
do
        REALDIR="$(dirname "$(realpath -m "$i")")/$(basename "$i")"
        for j in "$i" "$REALDIR"
        do
                grep -v "^${j}$" "$tmpfile" > "$otmpfile" || true
                mv "$otmpfile" "$tmpfile"
        done
done

chmod --reference="${file}" "${tmpfile}" || chmod $(stat -c %a "${file}") "${tmpfile}"
chown --reference="${file}" "${tmpfile}" || chown $(stat -c %U "${file}") "${tmpfile}"

mv -Z "${tmpfile}" "${file}" || mv "${tmpfile}" "${file}"

trap "" EXIT
exit 0
