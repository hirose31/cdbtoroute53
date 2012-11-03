#!/usr/bin/env bash

# small helper to aid migrating lots of domains

if [[ -z "$1" || -z "$2" ]]; then
  echo "usage: migrate.sh <domain.com> <zoneid>"
  echo "to create a new zone in route53:"
  echo "  $ cli53 create <domain.com>"
  exit 1
fi

./cdbtoroute53.pl -z $1 | ./dnscurl.pl -c -z $2
