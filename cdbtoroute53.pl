#!/usr/bin/env perl

# Copyright 2010 Amazon Technologies, Inc.
# Licensed under the Apache License, Version 2.0 (the "License");
#
# You may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#
# http://aws.amazon.com/apache2.0
#
# This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied.
#
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 cdbtoroute53.pl

cdbtoroute53.pl - Convert a TinyDNS CDB, or the differences between two
                  TinyDNS CDBs, to Amazon Route 53 ChangeResourceRecordSetsRequest
                  XML

=head1 SYNOPSIS

This script generates CreateHostedZoneRequest XML.

Dependencies: Data::GUID Net::DNS CDB_File

For help, try:

cdbtoroute53.pl --help

Usage example:

cdbtoroute53.pl --zonename example.com [--previous-cdb old.cdb] --cdb data.cdb

=head1 OPTIONS

=over 8

=item B<--help>

Print a help message and exits.

=item B<--zonename> [zonename]

CDBs contain records that span many zones. This script operates on just one zone at a time,
specify the zone with this option.

=item B<--previous-cdb> [cdbfile]

If this argument is supplied, this script will detect the differences between this CDB
and the CDB supplied by the --cdb argument. This set of differences will be translated
into a set of DELETE and CREATE changes.

=item B<--cdb> [cdbfile]

The CDB file to parse for the current desired state of DNS data.

=back

=cut

use warnings;
use strict;
use Getopt::Long;
use Pod::Usage;
use Data::GUID;
use CDB_File;
# requires Net::DNS >= 0.68
use Net::DNS::Domain;
use Net::DNS::DomainName;
use Net::DNS::RR;
use Net::DNS::Text;

# Net::DNS:RR to Value conversion
my $TYPES = {
    A     => sub { $_[0]->address; },
    AAAA  => sub { $_[0]->address; },
    SOA   => sub { my ($r)=@_; join(" ", $r->mname.".", $r->rname.".", $r->serial,
                       $r->refresh, $r->retry, $r->expire, $r->minimum); },
    NS    => sub { $_[0]->nsdname."."; },
    TXT   => sub { "\"" . join("\" \"", $_[0]->char_str_list()) . "\""; },
    CNAME => sub { $_[0]->cname."."; },
    MX    => sub { my ($r)=@_; $r->preference ." ". $r->exchange."."; },
    PTR   => sub { $_[0]->ptrdname."."; },
    SRV   => sub { my ($r)=@_; join(" ", $r->priority, $r->weight, $r->port,$r->target."."); },
    SPF   => sub { "\"" . join("\" \"", $_[0]->char_str_list()) . "\""; },
};

my $help          = 0;
my $zonename      = "";
my $cdb           = "";
my $previous_cdb  = "";

my $options = GetOptions(
    "previous-cdb=s"    => \$previous_cdb,
    "cdb=s"             => \$cdb,
    "zonename=s"        => \$zonename,
    "help"              => \$help,
);

if ($help or !$options or $zonename eq "" or $cdb eq "") {
    pod2usage(1);
    exit;
}

# Canonicalise the zone we are searching for
my $zone = new Net::DNS::Domain($zonename)->string;

# Parse a TinyDNS CDB and convert into a perl hash
sub parse_cdb {
    my %data;
    my $zone = $_[0];
    my $cdb = $_[1];

    tie %data, 'CDB_File', $cdb or die "$0: can't tie to $cdb: $!\n";

    my $parsed_tree = {};

    my $key;
    my $value;

    while (($key, $value) = each %data) {
        my $domain = Net::DNS::DomainName->decode( \$key, 0, {} )->name . '.';

        # Ignore domains outside of our zone
        next if ($domain !~ m/$zone$/);

        my ( $type , $djbcode, $ttl, $ttd_l, $ttd_h) = unpack("n C N NN", $value);

        if ($ttd_l != 0 || $ttd_h != 0) {
            die "Encountered a DJB 'time to die' for $domain . Amazon Route 53 does not support time to die functionality";
        }

        # Does this record have a location code?
        if ($djbcode != 42 && $djbcode != 61) {
            die "Encountered a record with a location code. Amazon Route 53 does not support location codes";
        }

        # If the third byte is 42, this is a wildcard record
        if ($djbcode == 42) {
            $domain = "*." . $domain;
        }

        # Convert into a Net::DNS::RR object
        my $rdata = substr($value, 15);
        my $rr = Net::DNS::DomainName->new( $domain )->encode(0, {}) .
                 pack("n", $type) . pack("n", 1) . pack("N", $ttl) .
                 pack("n", length($rdata)) . $rdata;
        my ($rrobj, $offset) = Net::DNS::RR->decode(\$rr, 0);

        # Is this record of a supported type?
        if (!defined( $TYPES->{ $rrobj->type })) {
            die ("Encountered a record of type '" . $rrobj->type . "' for '$domain'. Amazon Route 53 does not currently support this record type");
        }

        # Check that the TTLs match
        if (defined($parsed_tree->{ $domain }->{ $rrobj->type }->{TTL})) {
            if ($parsed_tree->{ $domain }->{ $rrobj->type }->{TTL} != $rrobj->ttl) {
                die("Encountered multiple TTL values for record of type '" . $rrobj->type . "' for name '$domain'");
            }
        }
        else {
            $parsed_tree->{ $domain }->{ $rrobj->type }->{TTL} = $rrobj->ttl;
        }

        push ( @{ $parsed_tree->{ $domain }->{ $rrobj->type }->{ResourceRecord} }, $TYPES->{$rrobj->type}($rrobj) );
    }

    return $parsed_tree;
}

sub append_change
{
    my ($action, $domain, $type, $resourceRecords) = @_;

    printf(q{
      <Change>
        <Action>%s</Action>
        <ResourceRecordSet>
          <Name>%s</Name>
          <Type>%s</Type>
          <TTL>%d</TTL>
},
            $action,
            $domain,
            $type,
            $resourceRecords->{TTL},
           );
    print "          <ResourceRecords>\n";
    foreach my $rr (@{ $resourceRecords->{ResourceRecord} }) {
        print "            <ResourceRecord><Value>$rr</Value></ResourceRecord>\n";
    }
    print q{          </ResourceRecords>
        </ResourceRecordSet>
      </Change>
};
}

sub arrays_equal
{
    my ($a, $b) = @_;

    my @a = sort(@{ $a });
    my @b = sort(@{ $b });

    if (length(@a) != length(@b)) {
        return 0;
    }

    for (my $i = 0; $i < scalar @a; $i++) {
        if ($b[ $i ] ne $a[ $i ]) {
            return 0;
        }
    }

    return 1;
}

my $previous_state = {};

if ($previous_cdb ne "") {
    $previous_state = parse_cdb($zone, $previous_cdb);
}

my $desired_state = parse_cdb($zone, $cdb);

print qq{<?xml version="1.0" encoding="UTF-8"?>\n<ChangeResourceRecordSetsRequest xmlns="https://route53.amazonaws.com/doc/2012-02-29/">\n} .
      qq{  <ChangeBatch>\n    <Comment>Change made with cdbtoroute53.pl</Comment>\n    <Changes>\n};

# Create anything as neccessary
foreach my $domain (  keys %{ $desired_state } ) {
    foreach my $type ( keys %{ $desired_state->{$domain} } ) {
        next if $type =~ /^(SOA|NS)$/;
        if (defined($previous_state->{$domain}->{$type})) {

            # Do nothing if previous and desired state is the same
            if ($previous_state->{$domain}->{$type}->{TTL} == $desired_state->{$domain}->{$type}->{TTL} &&
                arrays_equal($previous_state->{$domain}->{$type}->{ResourceRecord},
                             $desired_state->{$domain}->{$type}->{ResourceRecord})) {
                # Remove from the previous state
                delete $previous_state->{$domain}->{$type};
                next;
            }

            append_change("DELETE", $domain, $type, $previous_state->{$domain}->{$type});
            delete $previous_state->{$domain}->{$type};
        }

        append_change("CREATE", $domain, $type, $desired_state->{$domain}->{$type});
    }
}

# Delete anything left dangling in the previous state
foreach my $domain (  keys %{ $previous_state } ) {
    foreach my $type ( keys %{ $previous_state->{$domain} } ) {
        append_change("DELETE", $domain, $type, $previous_state->{$domain}->{$type});
    }
}

print "</Changes></ChangeBatch></ChangeResourceRecordSetsRequest>\n";
