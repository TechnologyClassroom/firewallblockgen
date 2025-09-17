#!/bin/bash

# Convert list of IP addresses to CSV format with ASN lookup.
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

# This script depends on several projects.
# https://iptoasn.com/
# https://github.com/jedisct1/iptoasn-webservice
# curl
# jq
# sed
# echo
# bash
# tr
# cat
# date

# TODO Improve script to work with safe bash and unvalidated entries.
#set -euo pipefail
#set -euxo pipefail  # DEBUG

# Set these variables with the address and port that has iptoasn-webservice
# exposed. Default local API IP address is 0.0.0.0 and default port is 53661.
apiip=127.0.0.1
#apiport=80
apiport=53661


# Where is the file with IP addresses?
iplistfile="ip-to-asn-info.txt"

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

echo "This is just data for informational purposes. This could help influence"
echo "a decision for blocking an ASN or making firewall changes if necessary."
echo

# CSV column headers
echo "IP,ASN,AS Description,Country,Date"
while read -r IPTOASN; do
  # TODO Validate IP is a valid IPv4 or IPv6 address.
  validateip=$(echo "$IPTOASN" \
    | grep -Eo \
      -e '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' `# IPv4` \
      -e '^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]).){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]).){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$' `# IPv6` \
    | wc -l)
  if [ "$validateip" -gt 0 ]; then
    # Make iptoasn-webservice request.
    curl -s -H'Accept: application/json' "$apiip:$apiport/v1/as/ip/$IPTOASN" \
      | jq '"\(.ip),AS\(.as_number),\(.as_description),\(.as_country_code)"' `# Format as CSV.` \
      | sed 's/"//g' `# Remove double quotes.` \
      | sed "s/$/,$today/" `# Add date.` \
      | sed 's/ASnull,null,null/ASN not announced,ASN not announced,ZZ/g' `# Identify unannounced ASNs.`
  else
    # Identify unvalidated entries.
    echo "$IPTOASN,Invalid IP,IP did not pass validation,ZZ,$today"
  fi
done < "$iplistfile"

# Output should look something like this:
#185.39.19.47,ASN not announced,20250614
#199.168.150.161,AS62907 ZSCALER (US),20250614

echo -e "\nThese -e switches can be used along with grep -v to exclude these"
echo "addresses from output of additional log analysis if necessary:"
sed 's/^/-e "/g;s/$/"/g' "$iplistfile" \
  | tr '\n' ' '
echo

exit 0
