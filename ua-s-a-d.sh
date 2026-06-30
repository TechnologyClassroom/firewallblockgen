#!/bin/bash

# ua-s-a-d.sh
# ua-s-a-d.sh (user-agent search and deny) scans web logs for crawlers
# masquerading as a collection of desktop user-agents to try to fly under the
# radar of traditional firewall tools and feed the matching IPs to reaction.
# Version 20260630

# Copyright (C) 2026 Michael McMahon
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Important items to take note of:
# - Overuse of this tool will likely ban VPNs.
# - The user-agent list should be curated based on specific abuse patterns
#   found in your logs. ua-s-a-d.sh pairs well with my LogReview scripts to
#   identify larger patterns of user-agents being used by botnets.
#   https://github.com/TechnologyClassroom/LogReview/
# - The relevant list of user-agents will likely evolve over time so
#   periodically review and update the list.
# - The deny portion depends on reaction which is a modern alternative to
#   fail2ban. https://reaction.ppom.me/
# - Currently, this script only works with the combined log format from Apache2
#   and NGINX.
# - Currently, this script only works with several hard-coded values.
# - ua-s-a-d.sh lives in the
# https://github.com/TechnologyClassroom/firewallblockgen/ repository.

# How do I use this script?
# 1. Place a list of user-agents into the `user-agent-list.txt` file in the
#    same directory as this script with one user-agent on each line.
# 2. Make sure that the script is configured to match your environment such as
#    pointing to your log file location, able to read your log format, and that
#    your reaction naming is the same.
# 3. Run this command to run this script from the command line of a system that
#    meets the dependencies.
#      bash ua-s-a-d.sh
#    (Optionally) The script can be run against a different user-agent list
#    than the default location of the user-agent list.
#      bash ua-s-a-d.sh user-agent-list.txt
# 3. If successful, IP addresses that match 3 or more of the lists will be
#    banned with reaction. Review the behavior of the IP addresses in
#    `crawlpattern.txt` to check for errors.
# 4. If everything looks correct, run this script as needed either manually
#    like so:
#      while true; do bash ua-s-a-d.sh ; sleep 600 ; date; done
#    or as a SystemD service.

# This script depends on these projects:
#   ipset, iptables, reaction, bash, sed, echo, grep, cp, cat, rm, awk, date,
#   mkdir, touch, sort, uniq, wc, bzcat, and zcat

# TODO Test if this script works with safe bash.
#set -euo pipefail
#set -euxo pipefail  # DEBUG

ualist=${1:-user-agent-list.txt}
log=${LOG:-/var/log/nginx/access.log}

# Check if the user-agent list can be read.
if [ ! -r "$ualist" ]; then
  echo "ua-s-a-d.sh: Cannot read user-agent list: $ualist" >&2
  exit 1
fi
# Validate whether the user-agent list has data in it.
if ! grep -Eq '^[[:space:]]*[^[:space:]#]' "$ualist"; then
  echo "ua-s-a-d.sh: No user-agents in $ualist (only blanks/comments)" >&2
  exit 1
fi
# TODO Validate whether the user-agent list has user-agents in it.

# Create descriptive filenames for user-agent lists: browser+majorversion+os, e.g.
# c145win, e144win, c145mac.
dfn() {
  case $1 in
    *Edg/*)             b=e; v=${1##*Edg/} ;;
    *OPR/*)             b=o; v=${1##*OPR/} ;;
    *Chrome/*)          b=c; v=${1##*Chrome/} ;;
    *Firefox/*)         b=f; v=${1##*Firefox/} ;;
    *Version/*Safari/*) b=s; v=${1##*Version/} ;;
    *)                  b=x; v=0 ;;
  esac
  v=${v%%.*}; v=${v%% *}
  case $1 in
    *Windows*)              o=win ;;
    *Macintosh*|*"Mac OS"*) o=mac ;;
    *Android*)              o=android ;;
    *iPhone*|*iPad*)        o=ios ;;
    *Linux*|*X11*)          o=lin ;;
    *)                      o=x ;;
  esac
  printf '%s%s%s' "$b" "$v" "$o"
}

date
echo "ipset size:"
ipset save | wc -l

echo "Building lists..."

# Clean old user-agent IP files.
rm -f ./*-ips.txt

# For each user-agent in the list, save each unique IPs whose user-agent field is an exact match.
n=0
while IFS= read -r ua; do
  case $ua in
    ''|\#*) continue ;;
  esac
  n=$((n + 1))
  out="$(dfn "$ua")-ips.txt"
  [ -e "$out" ] && out="$(dfn "$ua")-$(printf '%02d' "$n")-ips.txt"
  awk -F'"' -v ua="$ua" 'NF>=2 && $(NF-1)==ua { split($1,a," "); print a[1] }' "$log" \
    | sort -u \
    > "$out"
  # To review rotated/compressed logs: Replace the awk input with something like this:
  #   bzcat -f "$log"* \
  #     | awk -F'"' -v ua="$ua" 'NF>=2 && $(NF-1)==ua { split($1,a," "); print a[1] }' \
  #     | sort -u \
  #     > "$out"
done < "$ualist"

touch blocked.txt

echo "Building list of new IPs that match the pattern..."
cat ./*-ips.txt \
  | sort | uniq -c \
  | awk '$1 > 2' \
  | sort -n \
  | awk '{print $2 }' \
  > crawlpattern.txt

# Dev note: I removed this snippet from below the cat line as the IPs were not
# permanently blocked by the reaction command and they came back.
#  | grep -v -f blocked.txt \

wc -l crawlpattern.txt
# 38220

# Block the findings with reaction if available.
if command -v <the_command> >/dev/null 2>&1 ; then
  for i in $(cat crawlpattern.txt) ; do
    reaction trigger web1.badbots ip="$i"
  done
fi

mkdir -p previouslyfound
cp crawlpattern.txt previouslyfound/"$(date +%Y-%m-%d-%H-%M)"crawlpattern.txt
cat previouslyfound/*crawlpattern.txt | sort -u > blocked.txt

date
echo "ipset size:"
ipset save | wc -l
