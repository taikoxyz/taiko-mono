#
# Copyright © 2010 Raphaël Hertzog <hertzog@debian.org>
# Copyright © 2011-2015 Guillem Jover <guillem@debian.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# shellcheck shell=sh

# Standard ANSI colors and attributes.
COLOR_NORMAL=''
COLOR_RESET='[0m'
COLOR_BOLD='[1m'
COLOR_BLACK='[30m'
COLOR_RED='[31m'
COLOR_GREEN='[32m'
COLOR_YELLOW='[33m'
COLOR_BLUE='[34m'
COLOR_MAGENTA='[35m'
COLOR_CYAN='[36m'
COLOR_WHITE='[37m'
COLOR_BOLD_BLACK='[1;30m'
COLOR_BOLD_RED='[1;31m'
COLOR_BOLD_GREEN='[1;32m'
COLOR_BOLD_YELLOW='[1;33m'
COLOR_BOLD_BLUE='[1;34m'
COLOR_BOLD_MAGENTA='[1;35m'
COLOR_BOLD_CYAN='[1;36m'
COLOR_BOLD_WHITE='[1;37m'

setup_colors()
{
  : "${DPKG_COLORS=auto}"

  case "$DPKG_COLORS" in
  auto)
    if [ -t 1 ]; then
      USE_COLORS=yes
    else
      USE_COLORS=no
    fi
    ;;
  always)
    USE_COLORS=yes
    ;;
  *)
    USE_COLORS=no
    ;;
  esac

  if [ $USE_COLORS = yes ]; then
    COLOR_PROG="$COLOR_BOLD"
    COLOR_INFO="$COLOR_GREEN"
    COLOR_NOTICE="$COLOR_YELLOW"
    COLOR_WARN="$COLOR_BOLD_YELLOW"
    COLOR_ERROR="$COLOR_BOLD_RED"
  else
    COLOR_RESET=""
  fi
  FMT_PROG="$COLOR_PROG$PROGNAME$COLOR_RESET"
}

debug() {
  if [ -n "$DPKG_DEBUG" ]; then
    echo "DEBUG: $FMT_PROG: $*" >&2
  fi
}

error() {
  echo "$FMT_PROG: ${COLOR_ERROR}error${COLOR_RESET}: $*" >&2
  exit 1
}

warning() {
  echo "$FMT_PROG: ${COLOR_WARN}warning${COLOR_RESET}: $*" >&2
}

badusage() {
  echo "$FMT_PROG: ${COLOR_ERROR}error${COLOR_RESET}: $1" >&2
  echo >&2
  echo "Use '$PROGNAME --help' for program usage information." >&2
  exit 1
}
