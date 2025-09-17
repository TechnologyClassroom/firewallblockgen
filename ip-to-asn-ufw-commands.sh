#!/bin/bash

# Convert list of IP addresses to commands for UFW with ASN lookup.
#
# Copyright (C) 2024-2025 Michael McMahon
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

# TODO expand
# This script depends on these two projects.
# https://iptoasn.com/
# https://github.com/jedisct1/iptoasn-webservice

# Set these variables with the address and port that has iptoasn-webservice
# exposed.
apiip=127.0.0.1
#apiport=80
apiport=53661
today=$(date +%Y%m%d)

# Where is the file with IP addresses?
iplistfile="ip-to-asn-ufw.txt"

# Tests for dependencies

echo -e "Commands for UFW that can be run on a server to block these addresses if necessary.\n"

cat <<'END'
Throughout this script, $ufwipv6 references this command:
ufwipv6=$(ufw status numbered | grep "(v6)" | head -n 1 | awk '{print $1}' | sed 's/\[//g;s/\]//g')

END

# Debug API with this command:
#   curl -H'Accept: application/json' "192.168.50.102:80/v1/as/ip/8.8.8.8"

while read IPTOASN; do
  curl -s -H'Accept: application/json' "$apiip:$apiport/v1/as/ip/$IPTOASN" \
    | jq '"ufw insert 1 deny \(.ip) comment \"AS\(.as_number) \(.as_description) (\(.as_country_code))"' \
    | sed 's/\\//g' `# Remove extra backslash.` \
    | sed 's/ASnull null (null)/ASN not announced/g' `# Identify unannounced ASNs.` \
    | sed 's/^"//g' `# Remove leading double quote.` \
    | sed "s/\"$/ - $today\"/" `# Add date string.` \
    | sed -e '/:/s/insert 1 deny/insert $ufwipv6 deny/g' `# Only for IPv6, replace line 1 with $ufwipv6.`

# Output should look something like this:
#insert 1 deny 185.39.19.47 comment "ASN not announced - 20250614"
#insert 1 deny 199.168.150.161 comment "AS62907 ZSCALER (US) - 20250614"

# Edit the lines with some more fields with descriptive information about
# user-agent patterns and behavior to look something like this:
#insert 1 deny 199.168.150.161 comment "AS62907 ZSCALER (US) - No UA - Vuln scanner 90k hits 20250614"

done < "$iplistfile"

echo -e "\nThese -e switches can be used along with grep -v to exclude these addresses from output of additional log analysis if necessary:"
cat "$iplistfile" \
  | sed 's/^/-e "/g;s/$/"/g' \
  | tr '\n' ' '
echo

exit 0
