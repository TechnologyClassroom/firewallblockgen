#!/bin/bash

# cc-to-ipset-script.sh
# Generate scripts to block countries using ipset from a list of country codes.
# Version 20260629
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
#   https://www.ipdeny.com/ipblocks/
#   ipset, iptables, wget, bash, sed, echo, pwd, cd, mktemp, grep, sleep, date

# How do I use this script?
# 1. Place a list of country codes (CC) into the `cc-to-ipset-script.txt` file
#    in the same directory as this script with one CC on each line. Accepted CC
#    seem to be two letter CC as defined in ISO 2166-2. Read
#    <https://en.wikipedia.org/wiki/ISO_3166-2> for more information.
# 2. Run this command to run this script from the command line of a system that
#    meets the dependencies.
#      bash cc-to-ipset-script.sh
# 3. If successful, you will have files in the `./ipset/` directory. Copy those
#    to the server that you want to block those CCs on. Replace
#    `root@production.server:/root/ipset/` with the username, address, and
#    directory that you want to place the files in.
#      scp ipset/*-$(date +%Y%m%d).sh root@production.server:/root/ipset/
# 4. Login to the server.
#      ssh root@production.server
# 5. Change to the directory where you store the files.
#      cd ipset
# 6. Run the individual scripts like so.
#      bash cn-ipset-20260201.sh
#    If you are applying several from today, run all of them with this BASH
#    loop command:
#      for i in $(ls *$(date +%Y%m%d).sh); do echo $i; bash $i; done
#    If you are applying all of the scripts from a directory, run all of them
#    with this BASH loop command:
#      for i in $(ls *.sh); do echo $i; bash $i; done

set -euo pipefail
#set -euxo pipefail  # DEBUG

# Where is the file with the country code list?
asnlistfile="cc-to-ipset-script.txt"

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
while read -r CC || [ -n "$CC" ]; do
  # Validate the country code. Skip anything that is not two letters.
  if ! [[ "$CC" =~ ^[A-Za-z]{2}$ ]]; then
    echo "WARNING: Skipping invalid country code: '$CC'" >&2
    continue
  fi
  addressSet4="$CC-4"
  addressSet6="$CC-6"
  echo "Building $CC list in $(pwd)"
  # Download the CC list (ipdeny zone files are lowercase); skip on failure.
  if ! wget -qO "$CC-$today.txt" \
      "https://www.ipdeny.com/ipblocks/data/countries/${CC,,}.zone" \
      || [ ! -s "$CC-$today.txt" ]; then
    echo "WARNING: Download failed or empty for $CC. Skipping." >&2
    continue
  fi
  # Keep only valid IP/CIDR lines so a stray HTML error page cannot become an
  # ipset entry in the generated root script.
  sane="$(grep -E '^[0-9A-Fa-f:.]+(/[0-9]{1,3})?$' "$CC-$today.txt" || true)"
  if [ -z "$sane" ]; then
    echo "WARNING: no valid IP/CIDR lines for $CC; skipping." >&2
    continue
  fi
  # Count how large the ipset needs to be. Do not waste extra resources.
  ipv4max="$(printf '%s\n' "$sane" | grep -c -v ":" || true)"
  ipv6max="$(printf '%s\n' "$sane" | grep -c ":" || true)"
  {
    # Build ipset script.
    if [ "$ipv4max" -gt 0 ]; then
      # Create ipset.
      echo "ipset -exist -N $addressSet4 hash:net family inet maxelem $ipv4max"
      # Add CIDR/IP entries.
      printf '%s\n' "$sane" \
        | grep -v ":" \
        | sed "s|^|ipset -exist -A $addressSet4 |" \
        || true
      # Insert iptables rules only if they are not already present.
      echo "iptables -C INPUT -m set --match-set $addressSet4 src -j DROP 2>/dev/null || iptables -I INPUT 1 -m set --match-set $addressSet4 src -j DROP"
      echo "iptables -C FORWARD -m set --match-set $addressSet4 src -j DROP 2>/dev/null || iptables -I FORWARD 1 -m set --match-set $addressSet4 src -j DROP"
      # Adds the ipset to iptables for only ports 80 and 443 for tcp connections.
      # echo "iptables -C INPUT -p tcp -m multiport --dports 80,443 -m set --match-set $addressSet4 src -j DROP 2>/dev/null || iptables -I INPUT 1 -p tcp -m multiport --dports 80,443 -m set --match-set $addressSet4 src -j DROP"
      # echo "iptables -C FORWARD -p tcp -m multiport --dports 80,443 -m set --match-set $addressSet4 src -j DROP 2>/dev/null || iptables -I FORWARD 1 -p tcp -m multiport --dports 80,443 -m set --match-set $addressSet4 src -j DROP"
    fi
    if [ "$ipv6max" -gt 0 ]; then
      echo "ipset -exist -N $addressSet6 hash:net family inet6 maxelem $ipv6max"
      # Add CIDR/IP entries.
      printf '%s\n' "$sane" \
        | grep ":" \
        | sed "s|^|ipset -exist -A $addressSet6 |" \
        || true
      # Insert iptables rules only if they are not already present.
      echo "ip6tables -C INPUT -m set --match-set $addressSet6 src -j DROP 2>/dev/null || ip6tables -I INPUT 1 -m set --match-set $addressSet6 src -j DROP"
      echo "ip6tables -C FORWARD -m set --match-set $addressSet6 src -j DROP 2>/dev/null || ip6tables -I FORWARD 1 -m set --match-set $addressSet6 src -j DROP"
      # Adds the ipset to iptables for only ports 80 and 443 for tcp connections.
      # echo "ip6tables -C INPUT -p tcp -m multiport --dports 80,443 -m set --match-set $addressSet6 src -j DROP 2>/dev/null || ip6tables -I INPUT 1 -p tcp -m multiport --dports 80,443 -m set --match-set $addressSet6 src -j DROP"
      # echo "ip6tables -C FORWARD -p tcp -m multiport --dports 80,443 -m set --match-set $addressSet6 src -j DROP 2>/dev/null || ip6tables -I FORWARD 1 -p tcp -m multiport --dports 80,443 -m set --match-set $addressSet6 src -j DROP"
    fi
  } >> "$CC-ipset-$today.sh"
  # Copy the file to the ipset directory.
  mkdir -p "$OWD/ipset"
  cp "$CC-ipset-$today.sh" "$OWD/ipset"
  # Do not become the monster that you seek to extinguish.
  sleep 4
done < "$OWD/$asnlistfile"

echo -e "\nIf builds were successful, ipset scripts can be found in the"
echo -e "$OWD/ipset/ directory.\n"
echo "Copy the scripts to the servers that need the block and run them."

exit 0
