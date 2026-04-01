#!/bin/bash

# cc-to-ipset-script.sh
# Generate scripts to block countries using ipset from a list of country codes.
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

# TODO Improve script to work with safe bash and unvalidated entries.
#set -euo pipefail
#set -euxo pipefail  # DEBUG

# Where is the file with the country code list?
asnlistfile="cc-to-ipset-script.txt"

# What is today?
today=$(date +%Y%m%d)

echo -e "Building ipset scripts...\n"

# Original working directory.
OWD="$(pwd)"

# Change to a temporary directory.
cd "$(mktemp -d)" || exit

while read -r CC; do
  addressSet4="$CC-4"
  addressSet6="$CC-6"
  echo "Building $CC list in $(pwd)"
  # Download the CC list.
  wget -qO "$CC-$today.txt" "https://www.ipdeny.com/ipblocks/data/countries/$CC.zone"
  {
    # Destroy ipsets.
    # Note: This does not work for existing ipsets in use. You would need to make
    # different ipsets and swap them in.
    #echo "ipset -X $addressSet4" > "$CC-ipset-$today.sh"
    #echo "ipset -X $addressSet6" >> "$CC-ipset-$today.sh"
    # Create ipsets to block a CIDR range.
    echo "ipset -N $addressSet4 hash:net family inet"
    echo "ipset -N $addressSet6 hash:net family inet6"
    # Add CIDR to ipset.
    grep -v ":" "$CC-$today.txt" \
      | sed "s/^/ipset -A $addressSet4 /g"
    grep ":" "$CC-$today.txt" \
      | sed "s/^/ipset -A $addressSet6 /g"
    # Adds the ipset to iptables for all ports.
    echo "iptables -I INPUT 1 -m set --match-set $addressSet4 src -j DROP"
    echo "iptables -I FORWARD 1 -m set --match-set $addressSet4 src -j DROP"
    echo "ip6tables -I INPUT 1 -m set --match-set $addressSet6 src -j DROP"
    echo "ip6tables -I FORWARD 1 -m set --match-set $addressSet6 src -j DROP"
    # Adds the ipset to iptables for only ports 80 and 443 for tcp connections.
    # echo "iptables -I INPUT 1 -p tcp -m multiport --dports 80,443 -m set --match-set $addressSet4 src -j DROP"
    # echo "iptables -I FORWARD 1 -p tcp -m multiport --dports 80,443 -m set --match-set $addressSet4 src -j DROP"
    # echo "ip6tables -I INPUT 1 -p tcp -m multiport --dports 80,443 -m set --match-set $addressSet6 src -j DROP"
    # echo "ip6tables -I FORWARD 1 -p tcp -m multiport --dports 80,443 -m set --match-set $addressSet6 src -j DROP"
  } >> "$CC-ipset-$today.sh"
  # Copy the file to the ipset directory.
  mkdir -p "$OWD/ipset"
  cp "$CC-ipset-$today.sh" "$OWD/ipset"
  # Do not become the monster that you seek to extinguish.
  sleep 4
done < "$OWD/$asnlistfile"
