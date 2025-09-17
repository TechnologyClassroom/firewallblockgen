#!/bin/bash

# Convert list of ASN to scripts to block with ipset.
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

# This script depends on these projects:
# enjen.net
# wget
# ipset
# iptables
# bash
# sed
# echo
# grep
# sleep
# pwd
# cd
# mktemp
# date

today=$(date +%Y%m%d)

# Where is the file with the ASN list?
asnlistfile="asn-to-ipset-script.txt"

echo -e "Building ipset scripts...\n"

# Original working directory.
OWD="$(pwd)"

# Change to a temporary directory.
cd "$(mktemp -d)"

while read ASN; do
  echo "Building $ASN list in $(pwd)"
  # Download the ASN list.
  wget -qO "$ASN-$today.txt" "https://www.enjen.net/asn-blocklist/index.php?asn=$ASN&type=iplist&api=1"
  # Destroy ipsets.
  # Note: This does not work for existing ipsets in use. You would need to make
  # different ipsets and swap them in.
  # echo "ipset -X $ASN-4" > "$ASN-ipset-$today.sh"
  # echo "ipset -X $ASN-6" >> "$ASN-ipset-$today.sh"
  # Create ipsets to block a CIDR range.
  echo "ipset -N $ASN-4 hash:net family inet" >> "$ASN-ipset-$today.sh"
  echo "ipset -N $ASN-6 hash:net family inet6" >> "$ASN-ipset-$today.sh"
  # Add CIDR to ipset.
  grep -v ":" "$ASN-$today.txt" \
    | sed "s/^/ipset -A $ASN-4 /g" \
    >> "$ASN-ipset-$today.sh"
  grep ":" "$ASN-$today.txt" \
    | sed "s/^/ipset -A $ASN-6 /g" \
    >> "$ASN-ipset-$today.sh"
  # Add the ipset to iptables
  echo "iptables -I INPUT 1 -m set --match-set $ASN-4 src -j DROP" \
    >> "$ASN-ipset-$today.sh"
  echo "iptables -I FORWARD 1 -m set --match-set $ASN-4 src -j DROP" \
    >> "$ASN-ipset-$today.sh"
  echo "ip6tables -I INPUT 1 -m set --match-set $ASN-6 src -j DROP" \
    >> "$ASN-ipset-$today.sh"
  echo "ip6tables -I FORWARD 1 -m set --match-set $ASN-6 src -j DROP" \
    >> "$ASN-ipset-$today.sh"
  # Copy it to the ipset directory.
  mkdir -p "$OWD/ipset"
  cp "$ASN-ipset-$today.sh" "$OWD/ipset"
  # Do not become the monster that you seek to extinguish.
  sleep 4
done < "$OWD/$asnlistfile"
