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

test -n "$DEBUG" && set -x

case $(uname -s) in
  Darwin)
    cap="pbcopy"
    ;;
  *)
    test -n "$DISPLAY" && type xsel >&2 && cap="xsel -b"
    ;;
esac

sed '1!G;h;$!d' | while read line
do
  echo -- $line | cut -d^ -f1
  output=$(echo $line | cut -d^ -f2)
  test -n "$cap" && echo $output | tr -d '\n"' | eval $cap || echo $output
  echo '  Press ENTER to continue...'
  read enter </dev/tty
done
