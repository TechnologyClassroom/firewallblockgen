#!/bin/bash

# Convert list of IPs to script to block all through ipset and iptables.
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

# Where is the file with the IP list?
iplistfile="ip-to-ipset-script.txt"

# What should the names of the ipsets start with?
name="ddos"

echo -e "Building ipset script...\n"

cp "$iplistfile" "$name-$today.txt"
echo "Building $name list in $(pwd)"
# Download the list.
# Destroy ipsets.
# Note: This does not work for existing ipsets in use. You would need to make
# different ipsets and swap them in.
#echo "ipset -X $name-4" > "$name-ipset-$today.sh"
#echo "ipset -X $name-6" >> "$name-ipset-$today.sh"
# Create ipsets to block individual addresses.
echo "ipset -N $name-4 hash:ip family inet hashsize 2097152 maxelem 3000000" >> "$name-ipset-$today.sh"
echo "ipset -N $name-6 hash:ip family inet6 hashsize 2097152 maxelem 3000000" >> "$name-ipset-$today.sh"
# Create ipsets to block a CIDR range.
#echo "ipset -N $name-4 hash:net family inet" >> "$name-ipset-$today.sh"
#echo "ipset -N $name-6 hash:net family inet6" >> "$name-ipset-$today.sh"
# Add IPs to ipset script.
grep -v ":" "$name-$today.txt" \
  | sed "s/^/ipset -A $name-4 /g" \
  >> "$name-ipset-$today.sh"
grep ":" "$name-$today.txt" \
  | sed "s/^/ipset -A $name-6 /g" \
  >> "$name-ipset-$today.sh"
# Add the ipset to iptables
echo "iptables -I INPUT 1 -m set --match-set $name-4 src -j DROP" \
  >> "$name-ipset-$today.sh"
echo "iptables -I FORWARD 1 -m set --match-set $name-4 src -j DROP" \
  >> "$name-ipset-$today.sh"
echo "ip6tables -I INPUT 1 -m set --match-set $name-6 src -j DROP" \
  >> "$name-ipset-$today.sh"
echo "ip6tables -I FORWARD 1 -m set --match-set $name-6 src -j DROP" \
  >> "$name-ipset-$today.sh"
rm "$name-$today.txt"
