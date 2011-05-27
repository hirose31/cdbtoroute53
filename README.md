cdbtoroute53.pl
========================

ABSTRACT
------------------------

Convert a TinyDNS CDB, or the differences between two TinyDNS CDBs, to
Amazon Route 53 ChangeResourceRecordSetsRequest XML.

EXAMPLE
------------------------

    cdbtoroute53.pl --zonename example.com --cdb data.cdb > example.com.xml
    dnscurl.pl --keyname my-aws-account -- \
      -H "Content-Type: text/xml; charset=UTF-8" \
      -X POST \
      --upload-file ./example.com.xml \
      https://route53.amazonaws.com/2011-05-05/hostedzone/Z163DCRDMY61DH/rrset

ORIGINAL CODE
------------------------

* https://forums.aws.amazon.com/thread.jspa?threadID=56530

