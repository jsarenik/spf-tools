                 _|       |               |      
      __| __ \  |         __|  _ \   _ \  |  __| 
    \__ \ |   | __|_____| |   (   | (   | |\__ \ 
    ____/ .__/ _|        \__|\___/ \___/ _|____/ 
         _|


# SPF-tools

[![Join the chat at https://gitter.im/jsarenik/spf-tools][gitter-img]][gitter]

Simple tools for keeping the SPF TXT records tidy in order to fight
[10 maximum DNS look-ups](http://serverfault.com/questions/584708).

## Release notes

### 2019/10 - new domain spf-tools.eu.org

Domain name spf-tools.eu.org is used for testing now.

### 2016/11 - new records on output

spf-tools since version spf-tools/spf-tools@f4f51f7 do not
output merely `ip4` and `ip6` records, but also keep original `ptr`
and `exists` ones.


## General Usage

Your original TXT record which causes more than 10 DNS look-ups
should be saved as an otherwise unused subdomain TXT record
(e.g. `spf-orig.spf-tools.eu.org`).

Create a configuration file:

    cat > ~/.spf-toolsrc <<EOF
    DOMAIN=spf-tools.eu.org
    ORIG_SPF=spf-orig.spf-tools.eu.org
    DESPF_SKIP_DOMAINS=_spf.domain1.com:spf.domain2.org
    DNS_TIMEOUT=5
    DNS_SERVER=
    EOF

Now just call any of the scripts described below.


## Tools Description

### despf.sh

```
Usage: despf.sh [OPTION]... [DOMAIN]...
Decompose SPF records of a DOMAIN. Optionaly can
sort and unique them.
DOMAIN may be specified in an environment variable.

Available options:
  -s DOMAIN[:DOMAIN...]      skip domains, i.e. leave include
                             without decomposition
  -t N                       set DNS timeout to N seconds
  -h                         display this help and exit
```

`despf.sh` is a tool that resolves all `ip4` and `ip6` blocks
found in any included SPF subdomain. It prints all these blocks
`sort(1)`ed and `uniq(1)`ed to stdout, one per line.
Other output (`Getting ...`) is on stderr.

Example:

    ./despf.sh google.com
    Getting _spf.google.com
    Getting _netblocks.google.com
    Getting _netblocks2.google.com
    Getting _netblocks3.google.com
    ip4:173.194.0.0/16
    ip4:74.125.0.0/16
    ...
    ip6:2a00:1450:4000::/36
    ip6:2c0f:fb50:4000::/36

The `DNS_TIMEOUT` configuration variable sets number of seconds
for the `host -W SECS` command (the same as option `-t`, see
help).


### mkblocks.sh

`mkblocks.sh` tool is meant to parse a list of blocks produced by
despf.sh and prepare content of TXT records that all fit into one
UDP packet, splitting into more TXT records if needed.

One TXT record per line of standard output.

    ./despf.sh | ./normalize.sh | ./simplify.sh | ./mkblocks.sh


### compare.sh

Current SPF records can be verified by running `compare.sh`.
If the TXT records need an update, it will automatically run
the other tools to print out or copy into pastebuffer the
new TXT records in reverse order.

Best practice is to put those lines into DNS starting with the
last one. That's why `xsel.sh` reverses the input gathered from
`mkblocks.sh`.

The last record to update is root domain's record which just
contains an include. It should be always updated as the last one
and the prefix alternated between `spf` and `_spf` prefixes when
changing records, so the records are all consistent until the
root one is changed.


### xsel.sh

In order to semi-automate the task of updating the records,
pipe the output of `mkblocks.sh` to `xsel.sh`.


### normalize.sh

This script takes care of correct CIDR ranges. At the moment
only IPv4.

Example:

    $ ./normalize.sh <<EOF
    > ip4:207.68.169.173/30
    > ip4:207.68.169.175/30
    > ip4:65.55.238.129/26
    > EOF
    ip4:207.68.169.172/30
    ip4:207.68.169.172/30
    ip4:65.55.238.128/26


### simplify.sh

This script takes out individual IPv4 addresses which are already
contained in CIDR ranges.

    $ ./simplify.sh <<EOF
    > ip4:192.168.0.1
    > ip4:192.168.0.0/24
    > EOF
    ip4:192.168.0.0/24


### cloudflare.sh

Dependencies: [jq](https://stedolan.github.io/jq/),
[awk](https://www.gnu.org/software/gawk/),
[sed](https://www.gnu.org/software/sed/),
[grep](https://www.gnu.org/software/grep/)

Script to update pre-existing TXT SPF records for a domain according
to the input in DNS zone format using CloudFlare's API.

To use this script, file `.spf-toolsrc` in `$HOME` directory should
contain `TOKEN` variable definition which is then used
to connect to CloudFlare API. The file should also contain `DOMAIN`
and `ORIG_SPF` variables which stand for the target SPF domain
(e.g. `spf-tools.eu.org`) and original SPF record with includes
(e.g. `spf-orig.spf-tools.eu.org`) in order to use `runspftools.sh`
without modifying the script.

The script is written against v4 of https://api.cloudflare.com/

The only needed permissions for a custom API token are:
  - Zone.Zone: Read
  - Zone.DNS: Edit

Usage:

    ./despf.sh | ./normalize.sh | ./simplify.sh | ./iprange.sh | ./cloudflare.sh


### route53.sh

Dependencies: [jq](https://stedolan.github.io/jq/),
[aws](https://aws.amazon.com/cli/),
[awk](https://www.gnu.org/software/gawk/),
[sed](https://www.gnu.org/software/sed/),
[grep](https://www.gnu.org/software/grep/)

```
 Usage: route53.sh [OPTION]... [HOSTED_ZONE_ID]
  Script to update pre-existing TXT SPF records for
  a domain according to the input in DNS zone format.

  Available options:
    -t TTL                     set Time To Live for DNS records
    -a TXT RECORD              set aditional TXT record to domain (can be used multiple times)

  Default values:
    TTL = 300
```
Script to update pre-existing TXT SPF records for a domain according
to the input in DNS zone format.

The AWS CLI can be configured using `~/.aws/credentials` or using
environment variables: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
(find more details in [Configuring the AWS CLI](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-environment)
documentation.

Example:

    ./despf.sh | ./simplify.sh | ./mkblocks.sh | \
      ./route53.sh -a "google-site-verification=deadbeef" DEADBEEF


### iprange.sh

Extra dependencies: [iprange](https://github.com/firehol/iprange)

This script optimizes the IPv4 address block output (similar to, but
more than `simplify.sh` because it can join multiple networks into
one bigger).

Usage:

    ./despf.sh | ./iprange.sh

Example:

    $ ./despf.sh cont.spf-tools.eu.org
    ip4:13.111.0.0/24
    ip4:13.111.1.0/24
    ip4:13.111.2.0/24
    ip4:13.111.3.0/24
    $ ./despf.sh cont.spf-tools.eu.org | ./iprange.sh
    ip4:13.111.0.0/22

## Putting it all together

    ./despf.sh | ./normalize.sh | ./simplify.sh | ./iprange.sh \
      | ./mkblocks.sh | ./xsel.sh

## Free Ad

As we are successfully using a free eu.org domain, we are proud to
spread the word: Free domains: http://www.eu.org/

## Links

 * https://dmarcian.com/spf-survey/spf.spf-tools.eu.org
 * https://dmarcian.com/spf-survey/spf-orig.spf-tools.eu.org
 * http://www.kitterman.com/spf/validate.html
 * http://serverfault.com/questions/584708
 * http://www.openspf.org/SPF_Record_Syntax
 * http://tools.ietf.org/html/rfc7208#section-5.5
 * http://tools.ietf.org/html/rfc7208#section-14.1
 * https://space.dmarcian.com/too-many-dns-lookups/
 * https://nic.eu.org/


## License

    Copyright 2015-2019 spf-tools team (see AUTHORS)

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.


[gitter-img]: https://badges.gitter.im/Join%20Chat.svg
[gitter]: https://gitter.im/jsarenik/spf-tools
