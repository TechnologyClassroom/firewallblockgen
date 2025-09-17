#!/bin/bash

# Convert list of country codes to scripts to block with ipset.
#
# Copyright (C) 2025 Michael McMahon
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

# Accepted country codes seem to be two letter country codes as defined in ISO 2166-2.
# https://en.wikipedia.org/wiki/ISO_3166-2

# This script depends on these projects:
# ipdeny.com
# wget
# ipset
# iptables
# bash
# sed
# echo
# pwd
# cd
# mktemp
# grep
# sleep
# date

today=$(date +%Y%m%d)

# Where is the file with the country code list?
asnlistfile="cc-to-ipset-script.txt"

echo -e "Building ipset scripts...\n"

# Original working directory.
OWD="$(pwd)"

# Change to a temporary directory.
cd "$(mktemp -d)"

while read CC; do
  echo "Building $CC list in $(pwd)"
  # Download the CC list.
  wget -qO "$CC-$today.txt" "https://www.ipdeny.com/ipblocks/data/countries/$CC.zone"
  # Destroy ipsets.
  # Note: This does not work for existing ipsets in use. You would need to make
  # different ipsets and swap them in.
  #echo "ipset -X $CC-4" > "$CC-ipset-$today.sh"
  #echo "ipset -X $CC-6" >> "$CC-ipset-$today.sh"
  # Create ipsets to block a CIDR range.
  echo "ipset -N $CC-4 hash:net family inet" >> "$CC-ipset-$today.sh"
  echo "ipset -N $CC-6 hash:net family inet6" >> "$CC-ipset-$today.sh"
  # Add CIDR to ipset.
  grep -v ":" "$CC-$today.txt" \
    | sed "s/^/ipset -A $CC-4 /g" \
    >> "$CC-ipset-$today.sh"
  grep ":" "$CC-$today.txt" \
    | sed "s/^/ipset -A $CC-6 /g" \
    >> "$CC-ipset-$today.sh"
  # Add the ipset to iptables
  echo "iptables -I INPUT 1 -m set --match-set $CC-4 src -j DROP" \
    >> "$CC-ipset-$today.sh"
  echo "iptables -I FORWARD 1 -m set --match-set $CC-4 src -j DROP" \
    >> "$CC-ipset-$today.sh"
  echo "ip6tables -I INPUT 1 -m set --match-set $CC-6 src -j DROP" \
    >> "$CC-ipset-$today.sh"
  echo "ip6tables -I FORWARD 1 -m set --match-set $CC-6 src -j DROP" \
    >> "$CC-ipset-$today.sh"
  # Copy it to the ipset directory.
  mkdir -p "$OWD/ipset"
  cp "$CC-ipset-$today.sh" "$OWD/ipset"
  # Do not become the monster that you seek to extinguish.
  sleep 4
done < "$OWD/$asnlistfile"
