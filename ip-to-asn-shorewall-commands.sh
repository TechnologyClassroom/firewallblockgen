#!/bin/bash

# Convert list of IP addresses to commands for shorewall with ASN lookup.
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
iplistfile="ip-to-asn-shorewall.txt"

echo -e "Commands for shorewall that can be run on a server to block these addresses if necessary.\n"

# Debug API with this command:
#   curl -H'Accept: application/json' "192.168.50.102:80/v1/as/ip/8.8.8.8"

while read IPTOASN; do
  curl -s -H'Accept: application/json' "$apiip:$apiport/v1/as/ip/$IPTOASN" \
    | jq '"shorewall drop \(.ip) # AS\(.as_number) \(.as_description) (\(.as_country_code))"' \
    | sed 's/ASnull null (null)/ASN not announced/g' `# Identify unannounced ASNs.` \
    | sed 's/^"//g;s/"$//g' `# Remove leading and trailing double quotes.` \
    | sed "s/\$/ - $today/" `# Add date string.` \
    | sed -e '/:/s/shorewall /shorewall6 /g' `# Only for IPv6, replace shorewall with shorewall6.`

# Output should look something like this:
#shorewall drop 185.39.19.47 # ASN not announced
#shorewall drop 199.168.150.161 # AS62907 ZSCALER (US)

# Edit the lines with some more fields with descriptive information about
# user-agent patterns and behavior to look something like this:
#shorewall drop 45.88.188.10 # AS51167 CONTABO (DE) - AliyunSecBot UA - Vuln scanner 96k hits 20250605

done < "$iplistfile"

echo -e "\nThese -e switches can be used along with grep -v to exclude these addresses from output of additional log analysis if necessary:"
cat "$iplistfile" \
  | sed 's/^/-e "/g;s/$/"/g' \
  | tr '\n' ' '
echo

exit 0
