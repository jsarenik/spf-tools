#!/bin/sh -e
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
# Usage: ./despf <domain_with_SPF_TXT_record>

test -n "$DEBUG" && set -x

# Check for required tools
for cmd in host awk grep sed cut
do
  type $cmd >/dev/null
done

test -n "$DOMAIN" && DOMAIN_OVER=$DOMAIN

a="/$0"; a=${a%/*}; a=${a:-.}; a=${a#/}/; BINDIR=$(cd $a; pwd)
. $BINDIR/include/global.inc.sh
. $BINDIR/include/despf.inc.sh

# Read DNS_TIMEOUT if spf-toolsrc is present
test -r $SPFTRC && . $SPFTRC

usage() {
    cat <<-EOF
	Usage: despf.sh [OPTION]... [DOMAIN]...
	Decompose SPF records of a DOMAIN. Optionaly can
       	sort and unique them.
	DOMAIN may be specified in an environment variable.

	Available options:
	  -s DOMAIN[:DOMAIN...]      skip domains, i.e. leave include
	                             without decomposition
	  -t N                       set DNS timeout to N seconds
	  -d SERVER                  forcefully set queried DNS server
	                             and disable auto-detection
	  -h                         display this help and exit
	EOF
    exit 1
}

domain=${ORIG_SPF:-'spf-orig.spf-tools.eu.org'}
test -n "$DOMAIN_OVER" && domain=$DOMAIN_OVER

test -n "$domain" -o "$#" -gt 0 || usage
while getopts "t:s:d:h-" opt; do
  case $opt in
    t) test -n "$OPTARG" && DNS_TIMEOUT=$OPTARG;;
    s) test -n "$OPTARG" && DESPF_SKIP_DOMAINS=$OPTARG;;
    d) test -n "$OPTARG" && DNS_SERVER=$OPTARG;;
    *) usage;;
  esac
done
shift $((OPTIND-1))

# Domains specified as command line parameters override DOMAIN
test -z "$*" || domain="$*"

loopfile=$(mktemp /tmp/despf-loop-XXXXXXX)
echo random-non-match-tdaoeinthaonetuhanotehu > $loopfile
trap "cleanup $loopfile; exit 1;" INT QUIT

despfit "$domain" $loopfile | grep . || { cleanup $loopfile; exit 1; }
cleanup $loopfile
