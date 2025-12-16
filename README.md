# FirewallBlockGen

FirewallBlockGen is a collection of CLI BASH scripts to generate firewall rules
to block collections of IPs, ASN ranges, or countries.

Some of these scripts are still a bit of a work-in-progress (WIP), but they
work for me.

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

These scripts can be found at https://github.com/TechnologyClassroom/firewallblockgen/

## ASN Information and individual firewall rules

`ip-to-asn-info.sh`, `ip-to-asn-shorewall.sh`, `ip-to-asn-iptables.sh`, and
`ip-to-asn-ufw-commands.sh` depend on
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

These scripts can all be refactored into one, but I tend to use them
simulataneously so I am not motivated to do so. For example, I might be
reviewing logs on a server that uses shorewall and then a server that uses UFW
might go down so I leave what I was doing in the shorewall txt file, work on
the ufw files until done, and then get back to working on shorewall. Use with
caution.

## ASN and Country

`asn-to-ipset-script.sh` and `cc-to-ipset-script.sh` do not depend on
iptoasn-webservice and are for creating bash scripts that block either ASNs or
countries with `ipset`. These do depend on external web services. Use with
caution.
