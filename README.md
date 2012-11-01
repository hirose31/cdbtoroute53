# cdbtoroute53

Convert a TinyDNS CDB, or the differences between two TinyDNS CDBs, to
Amazon Route 53 ChangeResourceRecordSetsRequest XML.


### USAGE

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

Use ``--help`` on each program for more options.


### ORIGINAL CODE

* cdbtoroute53.pl: https://forums.aws.amazon.com/thread.jspa?threadID=56530
* dnscurl.pl: http://aws.amazon.com/developertools/9706686376855511
