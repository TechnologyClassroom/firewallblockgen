#!/bin/bash

# ip-to-asn-iptables-config.sh
# Generate iptables configuration rules including ASN information from a list of IP addresses.
# Version 20260705
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
#   https://iptoasn.com/
#   https://github.com/jedisct1/iptoasn-webservice
#   iptables, date, bash, echo, cat, grep, sed, curl, jq, tr, exit

# How did I use this script? (I now recommend using ipset instead.)
# 1. Run an instance of iptoasn-webservice either locally on your machine or
#    one accessible through your network.
# 2. Set the `apiip` and `apiport` values to point to iptoasn-webservice.
# 3. Place a list of IP addresses into the `ip-to-asn-iptables-config.txt`
#    file in the same directory as this script with one IP address on each line.
# 4. Run this command to run this script from the command line of a system that
#    meets the dependencies.
#      bash ip-to-asn-iptables-config.sh
# 5. Apply the configuration rules to the appropriate iptables configuration
#    file and restore the firewall rules to permanently block those addresses.
#
# If your server's networking slows down due to the increased number of rules
# or you run into a maximum number of firewall rules, I recommend migrating to
# using ipset.

# TODO Improve script to work with safe bash and unvalidated entries.
#set -euo pipefail
#set -euxo pipefail  # DEBUG

# Set these variables with the address and port that has iptoasn-webservice
# exposed. Default local API IP address is 0.0.0.0 and default port is 53661.
apiip=127.0.0.1
apiport=53661

# Where is the file with IP addresses?
iplistfile="ip-to-asn-iptables-config.txt"

# What is today?
today=$(date +%Y%m%d)

# Test that local dependencies are met.
for i in curl jq sed echo bash tr cat date; do
  if command -v "$i" >/dev/null 2>&1 ; then
    continue
  else
    echo "ERROR: $i not found! Install $i before continuing."
    exit 1
  fi
done

# Validate that the $iplistfile exists.
if [ ! -f $iplistfile ]; then
  echo "ERROR: $iplistfile not found! Make sure that $iplistfile"
  echo "exists with a list of IP addresses to lookup and that \$iplistfile is"
  echo "pointing to your file."
  exit 1
fi

echo -e "Rules for iptables that can be applied to a server to block these addresses if necessary.\n"

# Debug API with this command:
#   curl -H'Accept: application/json' "$apiip:$apiport/v1/as/ip/8.8.8.8"

# Test that iptoasn-webservice query is functional.
tmpdir=$(mktemp -d) || exit
# Make a curl response asking about Google's DNS.
http_response=$(curl -o "$tmpdir"/response.json -s -w "%{http_code}\n" \
  -H'Accept: application/json' $apiip:$apiport/v1/as/ip/8.8.8.8)
# Check if there was a 200 response.
if [ "$http_response" != "200" ]; then
  echo "ERROR: Could not connect to API! Check that your iptoasn-webservice"
  echo "instance is funtional. https://github.com/jedisct1/iptoasn-webservice"
  exit 1
else
  # Check if the query returns an AS description to test whether the query works.
  if [ "$(jq -e .as_description < "$tmpdir"/response.json \
        &>/dev/null; echo $?)" -gt 0 ]; then
    echo "ERROR: Test JSON response is invalid! Check that the ASN list is"
    echo "present and that iptoasn-webservice is functional."
    exit 1
  fi
fi

echo "ip-to-asn-iptables.sh provides firewall rules for along with additional information. This can"
echo -e"help include useful information with saved rules.\n"

# read also yields a final line with no trailing newline.
while read -r IPTOASN || [ -n "$IPTOASN" ]; do
  curl -s -H'Accept: application/json' "$apiip:$apiport/v1/as/ip/$IPTOASN" \
    | jq '"# AS\(.as_number) \(.as_description) (\(.as_country_code))-A state-check -s \(.ip) -j DROP"' \
    | sed 's/^"//g;s/"$//g' `# Remove leading and trailing double quote.` \
    | sed "s/)-A/) - $today\n-A/g" `# Add date string.` \
    | sed 's/ASnull null (null)/ASN not announced/g' `# Identify unannounced ASNs.`

# Output should look something like this:
## ASN not announced - 20250614
#-A state-check -s 185.39.19.47 -j DROP
## AS62907 ZSCALER (US) - 20250614
#-A state-check -s 199.168.150.161 -j DROP

# Edit the lines with some more fields with descriptive information about
# user-agent patterns and behavior to look something like this:
## AS132203 TENCENT-NET-AP-CN Tencent Building, Kejizhongyi Avenue (CN) - C58 UA - Unidentified crawler abusing search 2k hits 20250326
#-A state-check -s 43.134.176.147 -j DROP

done < "$iplistfile"

echo -e "\nThese -e switches can be used along with grep -v to exclude these addresses from output of additional log analysis if necessary:"
< "$iplistfile" \
  sed 's/^/-e "/g;s/$/"/g' \
  | tr '\n' ' '
echo

exit 0
