# cdbtoroute53

Convert a TinyDNS CDB, or the differences between two TinyDNS CDBs, to
Amazon Route 53 ChangeResourceRecordSetsRequest XML.


## USAGE

Install the following dependencies from CPAN:

```
Data::GUID Net::DNS CDB_File
```

Configure a secret file for dnscurl.pl called ``.aws-secrets``

```bash
$ cat .aws-secrets
%awsSecretAccessKeys = (
    'mykeyname' => {
        id => 'foobar',
        key => 'changeme',
    },
);

$ chmod 600 .aws-secrets
```

Then run (assumes data.cdb is in current dir):

```bash
cdbtoroute53.pl --zonename example.com | dnscurl.pl -c -z Z123456
```

Use ``--help`` on each program for more options. For pretty-printed output,
simply make sure that ``tidy`` is available on your path.

## OTHER TOOLS

[cli53](https://github.com/barnybug/cli53) is a great tool for interacting 
with route53 from the command line. To create a new zone:

```bash
$ cli53 create example.com
HostedZone:
  ResourceRecordSetCount: 2
  CallerReference: xxxx-xxxx-xxxx-xxxx-xxxx
  Config:
    Comment:
  Id: /hostedzone/Z123456
  Name: example.com.
ChangeInfo:
  Status: PENDING
  SubmittedAt: 2012-11-03T17:45:03.751Z
  Id: /change/C123456
DelegationSet:
  NameServers:
    - ns-1008.awsdns-62.net
    - ns-1319.awsdns-36.org
    - ns-1629.awsdns-11.co.uk
    - ns-247.awsdns-30.com
```

Then you can grab the zone id (Z123456 above) for the migration and update
your nameservers once finished.

## ORIGINAL CODE

* cdbtoroute53.pl: https://forums.aws.amazon.com/thread.jspa?threadID=56530
* dnscurl.pl: http://aws.amazon.com/developertools/9706686376855511
