#!/usr/bin/env bash

# small helper to aid migrating lots of domains

if [[ -z "$1" ]]; then
  echo "usage: cmigrate.sh <domain.com>"
  exit 1
fi

ZONEID=`cli53 create $1 | grep hostedzone | egrep -o 'Z.*$'`
echo "new zone id: $ZONEID"
echo
./cdbtoroute53.pl -z $1 > $1.txt
cat $1.txt | ./dnscurl.pl -c -z $ZONEID > $1.out
grep ErrorResponse $1.out >/dev/null
RET = $?

cat $1.out
rm $1.out

if [[ $RET -eq 0 ]]; then
  echo
  echo "looks like there was an error. change request saved in"
  echo "$1.txt. modify it and try resubmitting via command:"
  echo "  $ ./dnscurl.pl -z $ZONEID -c $1.txt"
  exit 1
else
  # no ErrorResponse, cleanup temp file
  rm $1.txt
fi
