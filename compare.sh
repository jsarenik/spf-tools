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
# Usage: ./compare.sh DOMAIN1 DOMAIN2

test -n "$DEBUG" && set -x

a="/$0"; a=${a%/*}; a=${a:-.}; a=${a#/}/; BINDIR=$(cd $a; pwd)
. $BINDIR/include/global.inc.sh

DOMAIN='spf-tools.eu.org'
ORIG_SPF='spf-orig.spf-tools.eu.org'

# Read settings from config file
test -r $SPFTRC && . $SPFTRC

DOMAIN=${1:-"$DOMAIN"}
ORIG_SPF=${2:-"$ORIG_SPF"}

a="/$0"; a=${a%/*}; a=${a:-.}; a=${a#/}/; BINDIR=$(cd $a; pwd)
PATH=$BINDIR:$PATH

temp=$(mktemp /tmp/$$.XXXXXXXX)

despf.sh $DOMAIN | normalize.sh | simplify.sh > ${temp}-1 2>/dev/null
despf.sh $ORIG_SPF | normalize.sh | simplify.sh > ${temp}-2 2>/dev/null

trap "rm ${temp}-*" EXIT
diff -u ${temp}-1 ${temp}-2
cmp ${temp}-* 2>/dev/null 1>&2 && echo "Everything OK" >&2 || {
  echo "Please update SPF TXT records of $DOMAIN!" 1>&2
  exit 1
}
