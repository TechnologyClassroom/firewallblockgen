#!/bin/bash

# ip-to-ipset-script.sh
# Convert list of IPs to script to block all through ipset and iptables.
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
#   ipset, iptables, bash, sed, echo, pwd, cd, mktemp, grep, sleep, date

# How do I use this script?
# 1. Place a list of IP addresses into the `ip-to-ipset-script.txt` file in
#    the same directory as this script with one IP address on each line.
# 2. Run this command to run this script from the command line of a system that
#    meets the dependencies.
#      bash ip-to-ipset-script.sh
# 3. If successful, you will have a new file. Copy the file to the server that
#    you want to block those addresses on. Replace
#    `root@production.server:/root/ipset/` with the username, address, and
#    directory that you want to place the files in.
#      scp *-$(date +%Y%m%d).sh root@production.server:/root/ipset/
# 4. Login to the server.
#      ssh root@production.server
# 5. Change to the directory where you store the files.
#      cd ipset
# 6. Run the individual scripts like so.
#      bash ddos-ipset-20260201.sh

set -euo pipefail
#set -euxo pipefail  # DEBUG

# Where is the file with the IP list?
iplistfile="ip-to-ipset-script.txt"

# What is today?
today=$(date +%Y%m%d)

# What should the names of the ipsets start with?
name="ddos"

if [ ! -f "$iplistfile" ]; then
  echo "ERROR: $iplistfile not found! Create it with one IP per line." >&2
  exit 1
fi
# Keep only valid IP/CIDR lines so malformed input cannot become an ipset
# entry in the generated root script.
sane="$(grep -E '^[0-9A-Fa-f:.]+(/[0-9]{1,3})?$' "$iplistfile" || true)"
if [ -z "$sane" ]; then
  echo "ERROR: no valid IP/CIDR lines in $iplistfile." >&2
  exit 1
fi

echo -e "Building ipset script...\n"

echo "Building $name ipset script in $(pwd)/$name-ipset-$today.sh file..."
{
  # IPv4
  # Destroy ipsets.
  # Note: This does not work for existing ipsets in use. You would need to make
  # different ipsets and swap them in.
  #echo "ipset -X $name-4" > "$name-ipset-$today.sh"
  # Create ipsets to block individual addresses.
  echo "ipset -exist -N $name-4 hash:ip family inet maxelem 300000"
  # Add IPs to ipset script.
  printf '%s\n' "$sane" \
    | grep -v ":" \
    | sed "s|^|ipset -exist -A $name-4 |" \
    || true
  # Insert iptables rules only if they are not already present.
  echo "iptables -C INPUT -m set --match-set $name-4 src -j DROP 2>/dev/null || iptables -I INPUT 1 -m set --match-set $name-4 src -j DROP"
  echo "iptables -C FORWARD -m set --match-set $name-4 src -j DROP 2>/dev/null || iptables -I FORWARD 1 -m set --match-set $name-4 src -j DROP"
  # IPv6
  # Destroy ipsets.
  #echo "ipset -X $name-6" >> "$name-ipset-$today.sh"
  # Create ipsets to block individual addresses.
  echo "ipset -exist -N $name-6 hash:ip family inet6 maxelem 300000"
  # Add IPs to ipset script.
  printf '%s\n' "$sane" \
    | grep ":" \
    | sed "s|^|ipset -exist -A $name-6 |" \
    || true
  # Insert iptables rules only if they are not already present.
  echo "ip6tables -C INPUT -m set --match-set $name-6 src -j DROP 2>/dev/null || ip6tables -I INPUT 1 -m set --match-set $name-6 src -j DROP"
  echo "ip6tables -C FORWARD -m set --match-set $name-6 src -j DROP 2>/dev/null || ip6tables -I FORWARD 1 -m set --match-set $name-6 src -j DROP"
} >> "$name-ipset-$today.sh"

exit 0
