#!/usr/bin/perl -w

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

use Msql;
BEGIN {
    $| = 1;
    my $db = Msql->connect();
    if (Msql->getserverinfo lt 2) {
	print "1..0\n";
	exit;
    }
    print "1..14\n";
}
END {print "not ok 1\n" unless $loaded;}

######################### End of black magic.

use strict;
use vars qw($loaded);
$loaded = 1;
print "ok 1\n";

sub create {
    my($db,$tablename,$createexpression) = @_;
    my($query) = "create table $tablename $createexpression";
    local($Msql::QUIET) = 1;
    my $limit = 0;
    while (! $db->query($query)){
	die "Cannot create table: query [$query] message [$Msql::db_errstr]\n" if $limit++ > 1000;
	$tablename++;
	$query = "create table $tablename $createexpression";
    }
    $tablename;
}

{
    my($q);
    my $db = Msql->connect("","test");
    my($t) = create(
		    $db,
		    "TABLE00",
		    "( id char(4) not null, longish text(30) )");
    if (grep /^$t$/, $db->listtables) {
	print "ok 2\n";
    } else {
	print "not ok 2\n";
    }
    for (3..14) {
	$q = qq{insert into $t values \('00$_',\'}.bytometer(2**$_).qq{\'\)};
	if ($db->query($q)) {
	    print "ok $_\n";
	} else {
	    print "not ok $_\n";
	}
    }
    $q = qq{drop table $t};
    $db->query($q);
}


sub bytometer {
    my($byte) = @_;
    my($result,$i) = "";
    for ($i=5;$i<=$byte;$i+=5) {
	if ( $i==5 || substr($i,-2) eq "05" && $i<10000 ) {
	    $result .=  join "", "\n", "." x (4-length($i)), $i;
	} elsif ( $i<=10000 ) {
	    $result .=  join "", "." x (5-length($i)), $i;
	} elsif ( substr($i,-2) eq "10" ) {
	    $result .=  join "", "\n", "." x (9-length($i)), $i;
	} elsif ( substr($i,-1) eq "0" ) {
	    $result .=  join "", "." x (10-length($i)), $i;
	}
    }
    $result .= "." x ($byte%5);
    return $result;
}
