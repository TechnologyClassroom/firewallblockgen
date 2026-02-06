#!/bin/bash
#shellcheck disable=SC2016

# ip-to-asn-ufw-commands.sh
# Generate UFW commands to block IP addresses with ASN information in comments
# from a list of IP addresses.
# Version 20260205
#
# Copyright (C) 2024-2026 Michael McMahon
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
# https://iptoasn.com/
# https://github.com/jedisct1/iptoasn-webservice
# ufw, date, bash, echo, cat, head, grep, awk, sed, curl, jq, tr, exit

# How did I use this script? (I now recommend using ipset instead.)
# 1. Run an instance of iptoasn-webservice either locally on your machine or
#    one accessible through your network.
# 2. Set the `apiip` and `apiport` values to point to iptoasn-webservice.
# 3. Place a list of IP addresses into the `ip-to-asn-ufw-commands.txt` file in
#    the same directory as this script with one IP address on each line.
# 4. Run this command to run this script from the command line of a system that
#    meets the dependencies.
#      bash ip-to-asn-ufw-commands.sh
# 5. Run the commands on a server with UFW firewall to block those addresses.
#
# If your server's networking slows down due to the increased number of rules
# or you run into a maximum number of firewall rules, I recommend migrating to
# using ipset.

# TODO Improve script to work with safe bash and unvalidated entries.
#set -euo pipefail
#set -euxo pipefail  # DEBUG

# Set these variables with the address and port that has iptoasn-webservice
# exposed.
apiip=127.0.0.1
apiport=53661

# What is today?
today=$(date +%Y%m%d)

# Where is the file with IP addresses?
iplistfile="ip-to-asn-ufw-commands.txt"

# Tests for dependencies

echo "Commands for UFW that can be run on a server to block these addresses"
echo -e "if necessary.\n"

cat <<'END'
Throughout this script, $ufwipv6 references this command:
ufwipv6=$(ufw status numbered | grep "(v6)" | head -n 1 | awk '{print $1}' | sed 's/\[//g;s/\]//g')

END

# Debug API with this command:
#   curl -H'Accept: application/json' "192.168.50.102:80/v1/as/ip/8.8.8.8"

while read -r IPTOASN; do
  curl -s -H'Accept: application/json' "$apiip:$apiport/v1/as/ip/$IPTOASN" \
    | jq '"ufw insert 1 deny \(.ip) comment \"AS\(.as_number) \(.as_description) (\(.as_country_code))"' \
    | sed 's/\\//g' `# Remove extra backslash.` \
    | sed 's/ASnull null (null)/ASN not announced/g' `# Identify unannounced ASNs.` \
    | sed 's/^"//g' `# Remove leading double quote.` \
    | sed "s/\"$/ - $today\"/" `# Add date string.` \
    | sed -e '/:/s/insert 1 deny/insert $ufwipv6 deny/g' `# Only for IPv6, replace line 1 with $ufwipv6.`

# The `sed -e` line above generates a false positive for shellcheck's SC2016 so
# I disabled it on line 2. If this section gets rewritten, consider removing
# the disabled test.

# Output should look something like this:
#ufw insert 1 deny 185.39.19.47 comment "ASN not announced - 20250614"
#ufw insert 1 deny 199.168.150.161 comment "AS62907 ZSCALER (US) - 20250614"

# Edit the lines with some more fields with descriptive information about
# user-agent patterns and behavior to look something like this:
#insert 1 deny 199.168.150.161 comment "AS62907 ZSCALER (US) - No UA - Vuln scanner 90k hits 20250614"

done < "$iplistfile"

echo -e "\nThese -e switches can be used along with grep -v to exclude these"
echo "addresses from output of additional log analysis if necessary:"
< "$iplistfile" \
  sed 's/^/-e "/g;s/$/"/g' \
  | tr '\n' ' '
echo

exit 0
