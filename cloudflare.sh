#!/bin/sh
##############################################################################
#
# Copyright 2015 spf-tools team (see AUTHORS)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#     Unless required by applicable law or agreed to in writing, software
#     distributed under the License is distributed on an "AS IS" BASIS,
#     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#     See the License for the specific language governing permissions and
#     limitations under the License.
#
##############################################################################
#
# Script to update pre-existing TXT SPF records for
# a domain according to the input in DNS zone format.
#
# Requires jq(1) from http://stedolan.github.io/jq/
#
# Usage: ./despf.sh | ./simplify.sh | mkblocks.sh | \
#          mkzoneent.sh | ./cloudflare.sh <domain>
# E.g.: ... | ./cloudflare.sh spf-tools.eu.org

test -n "$DEBUG" && set -x

for cmd in jq awk sed grep
do
  type $cmd >&2 || exit 1
done

a="/$0"; a=${a%/*}; a=${a:-.}; a=${a#/}/; BINDIR=$(cd $a; pwd)
. $BINDIR/include/global.inc.sh

DOMAIN=${1:-'spf-tools.eu.org'}
APIURL="https://api.cloudflare.com/client/v4"

apicmd() {
  CMD=${1:-'GET'}
  test -n "$1" && shift
  REST=${1:-'/zones'}
  test -n "$1" && shift
  curl -X $CMD ${APIURL}${REST} \
    -s \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type:application/json" \
    "$@"
}

# Read TOKEN
test -r $SPFTRC && . $SPFTRC

test -n "$TOKEN" || { echo "TOKEN not set! Exiting." >&2; exit 1; }

test "$1" = "verify" && {
	apicmd GET "/user/tokens/verify"
	exit
}

idsfile=$(mktemp /tmp/cloudflare-ids-XXXXXX)
zonefile=$(mktemp /tmp/cloudflare-zone-XXXX)
cat > $zonefile
trap "rm -f $idsfile $zonefile $zonefile-data" EXIT

DOMAIN_ID=$(apicmd GET /zones | jq -r '.result | .[] | .name + ":" + .id' \
            | grep $DOMAIN) \
  || exit 1
DOMAIN_ID=$(echo $DOMAIN_ID | cut -d: -f2)

# only edit existing TXT records containig the "v=spf1" marker
apicmd GET "/zones/$DOMAIN_ID/dns_records?type=TXT" \
  | jq -r '.result | .[] | select ( .content | contains("v=spf1") ) | .name + ":" + .id' > $idsfile

while read line
do
  name=$(echo $line | cut -d^ -f1)
  content=$(echo $line | cut -d^ -f2 | tr -d \")
  id_to_change=$(grep "^$name" $idsfile | cut -d: -f2)

    cat > $zonefile-data <<EOF
{"type":"TXT","name":"$name","content":"$content"}
EOF

  if test -z "$id_to_change" 
  then
        echo -n "Creating TXT record $name... "
        apicmd PUT "/zones/$DOMAIN_ID/dns_records" \
          --data "@${zonefile}-data" | jq .success | grep -q true \
          && echo OK || echo error
  else
        echo -n "Updating TXT record $name with id $id_to_change... "
        apicmd PUT "/zones/$DOMAIN_ID/dns_records/$id_to_change" \
          --data "@${zonefile}-data" | jq .success | grep -q true \
          && echo OK || echo error
  fi
done < $zonefile
