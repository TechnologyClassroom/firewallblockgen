#!/bin/bash

# asn-to-ipset-script.sh
# Generate scripts to block ASNs with ipset from a list of ASNs.
# Version 20260201
#
# Copyright (C) 2025-2026 Michael McMahon
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

# This script depends on these projects:
#   https://www.enjen.net/asn-blocklist/readme.php
#   ipset, iptables, wget, bash, sed, echo, grep, sleep, pwd, cd, mktemp, pwd,
#   cp, and date

# How do I use this script?
# 1. Place a list of ASNs into the `asn-to-ipset-script.txt` file in the same
#    directory as this script with one ASN on each line.
# 2. Run this command to run this script from the command line of a system that
#    meets the dependencies.
#      bash asn-to-ipset-script.sh
# 3. If successful, you will have files in the `./ipset/` directory. Copy those
#    to the server that you want to block those ASNs on. Replace
#    `root@production.server:/root/ipset/` with the username, address, and
#    directory that you want to place the files in.
#      scp ipset/*-$(date +%Y%m%d).sh root@production.server:/root/ipset/
# 4. Login to the server.
#      ssh root@production.server
# 5. Change to the directory where you store the files.
#      cd ipset
# 6. Run the individual scripts like so.
#      bash 21859-ipset-20260201.sh
#    If you are applying several from today, run all of them with this BASH
#    loop command:
#      for i in $(ls *$(date +%Y%m%d).sh); do echo $i; bash $i; done
#    If you are applying all of the scripts from a directory, run all of them
#    with this BASH loop command:
#      for i in $(ls *.sh); do echo $i; bash $i; done

set -euo pipefail
#set -euxo pipefail  # DEBUG

# Where is the file with the ASN list?
asnlistfile="asn-to-ipset-script.txt"

# What is today?
today=$(date +%Y%m%d)

echo -e "Building ipset scripts...\n"

# Original working directory.
OWD="$(pwd)"

# Change to a temporary directory (removed on exit).
TMPDIR_BUILD="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BUILD"' EXIT
cd "$TMPDIR_BUILD" || exit 1

# read also yields a final line with no trailing newline.
while read -r ASN || [ -n "$ASN" ]; do
  # Validate the ASN; skip anything that is not all digits.
  if ! [[ "$ASN" =~ ^[0-9]+$ ]]; then
    echo "WARNING: skipping invalid ASN: '$ASN'" >&2
    continue
  fi
  echo "Building $ASN list in $(pwd)"
  # Download the ASN list; skip the ASN on a failed or empty download.
  if ! wget -qO "$ASN-$today.txt" \
      "https://www.enjen.net/asn-blocklist/index.php?asn=$ASN&type=iplist&api=1" \
      || [ ! -s "$ASN-$today.txt" ]; then
    echo "WARNING: download failed or empty for AS$ASN; skipping." >&2
    continue
  fi
  # Keep only valid IP/CIDR lines so a stray HTML error page cannot become an
  # ipset entry in the generated root script.
  sane="$(grep -E '^[0-9A-Fa-f:.]+(/[0-9]{1,3})?$' "$ASN-$today.txt" || true)"
  if [ -z "$sane" ]; then
    echo "WARNING: no valid IP/CIDR lines for AS$ASN; skipping." >&2
    continue
  fi
  {
    # Create ipsets (idempotent; large maxelem for big ASNs).
    echo "ipset -exist create $ASN-4 hash:net family inet maxelem 200000"
    echo "ipset -exist create $ASN-6 hash:net family inet6 maxelem 200000"
    # Add CIDR/IP entries.
    printf '%s\n' "$sane" | grep -v ":" | sed "s|^|ipset -exist add $ASN-4 |" || true
    printf '%s\n' "$sane" | grep ":"    | sed "s|^|ipset -exist add $ASN-6 |" || true
    # Insert iptables rules only if they are not already present.
    echo "iptables -C INPUT -m set --match-set $ASN-4 src -j DROP 2>/dev/null || iptables -I INPUT 1 -m set --match-set $ASN-4 src -j DROP"
    echo "iptables -C FORWARD -m set --match-set $ASN-4 src -j DROP 2>/dev/null || iptables -I FORWARD 1 -m set --match-set $ASN-4 src -j DROP"
    echo "ip6tables -C INPUT -m set --match-set $ASN-6 src -j DROP 2>/dev/null || ip6tables -I INPUT 1 -m set --match-set $ASN-6 src -j DROP"
    echo "ip6tables -C FORWARD -m set --match-set $ASN-6 src -j DROP 2>/dev/null || ip6tables -I FORWARD 1 -m set --match-set $ASN-6 src -j DROP"
  } >> "$ASN-ipset-$today.sh"
  # Create target directory if it does not exist.
  mkdir -p "$OWD/ipset"
  # Copy ipset script to the ipset directory.
  cp "$ASN-ipset-$today.sh" "$OWD/ipset"
  # Do not become the monster that you seek to extinguish.
  sleep 4
done < "$OWD/$asnlistfile"

echo -e "\nIf builds were successful, ipset scripts can be found in the"
echo -e "$OWD/ipset/ directory.\n"
echo "Copy the scripts to the servers that need the block and run them."

exit 0
