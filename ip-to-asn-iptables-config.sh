#!/bin/bash

# ip-to-asn-iptables-config.sh
# Generate iptables configuration rules including ASN information from a list of IP addresses.
# Version 20260626
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

# What is today?
today=$(date +%Y%m%d)

# Where is the file with IP addresses?
iplistfile="ip-to-asn-iptables-config.txt"

echo -e "Rules for iptables that can be applied to a server to block these addresses if necessary.\n"

# Debug API with this command:
#   curl -H'Accept: application/json' "192.168.50.102:80/v1/as/ip/8.8.8.8"

if [ ! -f "$iplistfile" ]; then
  echo "ERROR: $iplistfile not found! Create it with one IP per line." >&2
  exit 1
fi

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
