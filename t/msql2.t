#!/usr/bin/perl -w

use Msql;
BEGIN {
    $| = 1;
    my $db = Msql->connect();
    if (Msql->getserverinfo lt 2) {
	print "1..0\n";
	exit;
    }
    print "1..37\n";
}
END {print "not ok 1\n" unless $loaded;}

use strict;
use vars qw($loaded);
$loaded = 1;
print "ok 1\n";

{
    my($q,$what,@t,$i,$j);
    my $db = Msql->connect("","test");
    $t[0] = create(
		   $db,
		   "TABLE00",
		   "( id char(4) not null, longish text(30) )");
    $t[1] = create(
		   $db,
		   "TABLE00",
		   "( id char(4) not null, longish text(600) )");
    if (grep /^$t[0]$/, $db->listtables) {
	print "ok 2\n";
    } else {
	print "not ok 2\n";
    }
    for $i (0..14) {
	for $j (0,1) {
	    $q = qq{insert into $t[$j] values \('00$i',\'}.bytometer(2**$i).qq{\'\)};
	    my $ok = 3 + $i*2 + $j;
	    my $ret = $db->query($q);
	    if ($ret == 1) {
		print "ok $ok\n";
	    } else {
		print "not ok $ok: 'insert' returned [$ret], expected 1\n";
	    }
	}
    }
    $q = qq{select * from $t[0] where id < '006' and id > '002' order by id};
    if (($what = $db->query($q)->numrows) == 3) {
	print "ok 33\n";
    } else {
	print "not ok 33: $what\n";
    }
    $q = qq{select $t[0].id from $t[0] where id < '006' and id > '002' order by id desc};
    if (($what = $db->query($q)->numrows) == 3) {
	print "ok 34\n";
    } else {
	print "not ok 34: $what\n";
    }
    $q = qq{select * from $t[0] where id like '[_]'  order by id};
    if (($what = $db->query($q)->numrows) == 0) {
	print "ok 35\n";
    } else {
	print "not ok 35: $what\n";
    }
    my $index = cre_index($db,'INDEX00',"on $t[1] (id)","unique");
    print $index ? "" : "not ", "ok 36\n";

    $q = qq{select $t[0].id, $t[1].id from $t[0], $t[1] where $t[0].id=$t[1].id};
    if ($db->query($q)->numrows==15) {
	print "ok 37\n";
    } else {
	print "not ok 37: $what\n";
    }

    $q = qq{drop table $t[0]};
    $db->query($q);
    $q = qq{drop table $t[1]};
    $db->query($q);
}

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

sub cre_index {
    my($db,$indexname,$createexpression,$uniq) = @_;
    my($query) = "create $uniq index $indexname $createexpression";
    local($Msql::QUIET) = 1;
    my $limit = 0;
    while (! $db->query($query)){
	die "Cannot create index: query [$query] message [$Msql::db_errstr]\n" if $limit++ > 1000;
	$indexname++;
	$query = "create $uniq index $indexname $createexpression";
    }
    $indexname;
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
