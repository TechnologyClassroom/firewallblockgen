# FirewallBlockGen

FirewallBlockGen is a collection of BASH scripts to generate firewall rules to
block collections of IPs, ASN ranges, or countries.

For a visual demo of how I use the FirewallBlockGen scripts in context with my
other tools, watch my BSides CT 2025 presentation
[How to fight DDoS attacks from the command line](https://www.youtube.com/watch?v=BREJ58Y2Ez0)
for a more complete picture of the process that I use to thwart attacks.

Some of these scripts are still a bit of a work-in-progress (WIP), but they
work for me.

Use caution when modifying firewall rules. Try not to block yourself, your
organization, or your clients. Familiarize yourself with the process to undo a
change in the event that you do lock yourself out.

When [reviewing server logs](https://github.com/TechnologyClassroom/LogReview),
it is helpful to lookup ASNs as the additional context might help determine if
the pattern you are seeing is abuse or one our your internal proceses. With
this information, you can make informed decisions that might lead to blocking
individual addresses, blocking ASNs, blocking countries, or writing abuse
reports.

These scripts pair well with the
[LogReview](https://github.com/TechnologyClassroom/LogReview) project. For
automated handling, I recommend using
[reaction with ipset](https://reaction.ppom.me/actions/ipset.html) instead of
fail2ban.

The FirewallBlockGen scripts live in the
<https://github.com/TechnologyClassroom/firewallblockgen/> repository.

## Dependencies

These scripts have various dependencies. With the exception of
iptoasn-webservice, the tools generally assume to be run from a GNU/Linux
machine with dependencies that are simple to acquire.

### iptoasn-webservice

`ip-to-asn-info.sh`, `ip-to-asn-shorewall-commands.sh`,
`ip-to-asn-iptables-config.sh`, and `ip-to-asn-ufw-commands.sh` depend on
[iptoasn-webservice](https://github.com/jedisct1/iptoasn-webservice/) which can
be installed with `rust` and these commands:

```
git clone https://github.com/jedisct1/iptoasn-webservice/
cd iptoasn-webservice
cargo build --release
./target/release/iptoasn-webservice
```

If you want to use these scripts with iptoasn-webservice on another server,
create a reverse proxy with your favorite web server.

Within the scripts, configure the IP and port variables to point to where you
have iptoasn-webservice running.

`ip-to-asn-info.sh` has more debugging infrastructure so start with that one.

## ASN Information

`ip-to-asn-info.sh` is a useful wrapper for iptoasn-webservice that can provide
more information for a list of IP addresses. Instructions are in the file in
comments.

## Individual firewall rules

`ip-to-asn-info.sh`, `ip-to-asn-shorewall-commands.sh`,
`ip-to-asn-iptables-config.sh`, and `ip-to-asn-ufw-commands.sh` all generate
variations of commands to block IP addresses with firewall tools.

## ASN and Country blocking

Blocking by ASN or by country (geofencing) casts a much wider net than the
other scripts. `asn-to-ipset-script.sh` and `cc-to-ipset-script.sh` generate
BASH scripts that block ASNs or countries respectively with `ipset`. These do
depend on external web services. Always use caution when blocking this many
addresses.

`asn-to-ipset-script.sh` currently depends on
[enjen.net/asn-blocklist](https://www.enjen.net/asn-blocklist/readme.php)
for a list of CIDR for an ASN. `cc-to-ipset-script.sh` currently depends on
[IPdeny](https://www.ipdeny.com/ipblocks/) for a list of CIDR for a country.
`asn-to-ipset-script.sh` and `cc-to-ipset-script.sh` do not depend on
iptoasn-webservice.

## User-agent searching

Some bots will intentionally try to rotate through a list of user-agents to try
to fly under the radar of many other tools. `ua-s-a-d.sh` can be fed a list of
user-agents and if an IP uses three or more of the user-agents in the list, it
will ban them with reaction if present.
