#!/usr/bin/perl

$host = shift || "";

print "1..35\n";

use Msql;

package Msql;

# this Insert method is very expensive, and is only justified within
# the test case. I wouldn't recommend its use in production code

sub  Insert {
    my ($self, $table, @values) = @_;
    my ($sth,@namearr,$pack,$file,$line);
    my ($name,$type);

    $sth=$self->ListFields($table);
    $name=$sth->fetchinternal(NAME);
    $type=$sth->fetchinternal(TYPE);

    unless (@values == @{$name}){
	print join (":", @values), 
	"--", 
	join ("!", @namearr), 
	"in $table\n";
	Carp::croak("$table needs " . 
		    scalar @{$name} . 
		    " fields, got " . 
		    scalar @values . "\n");
    }
    my $query = "insert into $table ( ";
    $query .= join ",", @{$name};
    my @arr=();
    $query .= " ) values (";
    foreach (0..$#values){
	my $value = $values[$_];
	if ( $ {$type}[$_] == &CHAR_TYPE() ){
	    $value =~ s/'/\\'/gs;
	    $value = "'$value'";
	}
	push @arr, $value;
    }
    $query .= join ",", @arr;
    $query .= ")";
    $self->Query($query);
}

package main;

#You may connect in two steps: (1) Connect and (2) SelectDB...
( $dbh = Connect Msql $host)
    and print("ok 1\n") 
    or die "not ok 1: $Msql::db_errstr\n";

if ($dbh->SelectDB("test")){ 
    print("ok 2\n");
} else {
    die "not ok 2: $Msql::db_errstr
Please make sure that a database \"test\" exists
and that you can read and write on it
";
}

#Or you may call connect with two arguments, the first being the
#host, and the second being the DB

$dbh = Msql->Connect($host,"test")
    and print("ok 3\n") 
    or die "not ok 3: $Msql::db_errstr\n";

#First we create two tables that are certainly not there
@foundtable  =  $dbh->ListTables;
@foundtable{@foundtable} = (1) x @foundtable;
$goodtable = "TABLE00";
1 while $foundtable{++$goodtable};
push @tables, $goodtable;
1 while $foundtable{++$goodtable};
push @tables, $goodtable;


$dbh->Query("create table $tables[0] (one char(32), two char(32),
  three char (32))");

$dbh->Query("create table $tables[1] (one char(32),
  two char(32) not null, three char (32))");

$dbh->Insert($tables[0],qw(Anna Franz Otto));
$dbh->Insert($tables[0],qw(Sabine Thomas Pauline));
$dbh->Insert($tables[0],qw(Jane Paul Jah));
$dbh->Insert($tables[1],qw(Henry Francis James));
$dbh->Insert($tables[1],qw(Cashrel Beco Lotic));


$sth = $dbh->Query("select * from $tables[0]") or die $Msql::db_errstr;

($sth->numrows > 0) and print("ok 4\n") or print("not ok 4\n");
($sth->numfields == 3) and print ("ok 5\n") or print("not ok 5\n");
(@{$sth->name} == $sth->numfields) 
    and print ("ok 6\n") or print("not ok 6\n");
${$sth->table}[0] eq ${$sth->table}[1]
    and print ("ok 7\n") or print("not ok 7\n");
${$sth->table}[1] eq ${$sth->table}[2] 
    and print ("ok 8\n") or print("not ok 8\n");

&CHAR_TYPE == ${$sth->type}[0] 
    and print ("ok 9\n") or print("not ok 9\n");
$rowcnt=0;
while (@row = $sth->FetchRow()){
    $rowcnt++;
}
$sth->DataSeek(0);
while (@row = $sth->FetchRow()){
    $rowcnt++;
}
($rowcnt/2 == $sth->numrows)
    and print ("ok 10\n") or print("not ok 10\n");

$sth = $dbh->Query("select * from $tables[1]");

${$sth->is_not_null}[1] == 1 
    and print ("ok 11\n") or print("not ok 11\n");

( $dbh = Connect Msql($host,"test") )
    and print("ok 12\n") 
    or print "not ok 12: $Msql::db_errstr\n";

($sth1 = Query $dbh "select * from $tables[0]")
     or warn "Query had some problem: $Msql::db_errstr\n";
$sth2 = $dbh->Query("select * from $tables[1]")
     or warn "Query had some problem: $Msql::db_errstr\n";

$count=0;
while ($sth2->FetchRow and @row1=$sth1->FetchRow){
    $count++;
}
$count == 2  and print ("ok 13\n") or print("not ok 13\n"); 

undef ($sth2);

$count=0;
while (@row1=$sth1->FetchRow){
    $count++;
}
$count == 1 and print ("ok 14\n") or print("not ok 14\n");

# Yes, there's a typo:
#warn "testscript Expecting a syntax error:\n" if $^W;
{ # local $^W=0;
    $Msql::QUIET = 1;
  $sth = $dbh->Query  ("select * from $tables[0]
     where two = 'Thomas')");
}
$Msql::db_errstr =~ /error/
	and print("ok 15\n") or print("not ok 15\n");

# Yes, this one shouldn't succeed
eval "\@row=\$sth->FetchRow;";
if ($@){print "ok 16\n"} else {print "not ok 16\n"}

$sth = $dbh->Query  ("select * from $tables[0]
     where two = 'Thomas'")
     or warn "Query had some problem: $Msql::db_errstr\n";

@row=$sth->FetchRow or warn "$tables[0] didn't find a matching row";
$row[2] eq "Pauline" and print ("ok 17\n") or print("not ok 17\n");

@fieldnum{@{$sth->name}} = 0..@{$sth->name}-1;
$row[$fieldnum{"one"}] eq 'Sabine' 
    and print ("ok 18\n") or print("not ok 18\n");

( $dbh1 = Connect Msql($host,"test") )
    and print("ok 19\n") 
    or print "not ok 19\n";

$dbh1->database eq "test" and print("ok 20\n") or print("not ok 20\n");
$dbh1->sock =~ /^\d+$/ and print("ok 21\n") or print("not ok 21\n");

$dbh1->Query("drop table $tables[1]") and print("ok 22\n") or print("not ok 22\n");

@array=$dbh1->ListDBs;
grep( /^test$/, @array ) and print("ok 23\n") or print("not ok 23\n");

@array=$dbh1->ListTables;
grep( /^$tables[0]$/, @array )  and print("ok 24\n") or print("not ok 24\n");

( $dbh2 = Connect Msql($host,"test") )
    and print("ok 25\n") 
    or die "not ok 25\n";

$dbh2->host eq $host 
    and print("ok 26\n") 
    or die "not ok 26\n";

print "ok 27\n"; # $sth->host deprecated

$sth=$dbh2->Query("select one from $tables[0]");

$dbh1->Query("drop table $tables[0]");



sub create {"create table $tables[$_[0]] ( name char(40) not null, 
            num int primary key, country char(4), time real )";}
sub drop {"drop table $tables[$_[0]]";}

$C="AAAA"; $N=1;
$dbh1->Query(&create(0)) or die "Couldn't create: $Msql::db_errstr\n";
for (1..5){
    $dbh1->Insert($tables[0],$C++,$N++,$C++,rand);
    $dbh2->Insert($tables[0],$C++,$N++,$C++,rand);
}

$sth=$dbh1->Query("select * from $tables[0]");
$testseen=0;
while (@row = $sth->FetchRow){
    $testseen++;
}
$testseen==10  and print("ok 28\n") or print("not ok 28\n");

for (1..3){
    $dbh1->Query(&drop(0));
    $dbh1->Query(&create(1));
    $dbh2->Query(&drop(1));
    $dbh2->Query(&create(0));
}
($dbh1->Query(&drop(0)) ) and  print("ok 29\n") or print("not ok 29\n");

if ("@{$sth->length}" eq "40 4 4 8"){
    print "ok 30\n";
} else {
    print "not ok 30\n";
}

if ( $dbh1->Query("create table $tables[0] (FOO int)") ) { 
    print "ok 31\n" } else {print "not ok 31\n"};
if ( $dbh1->Query("drop table $tables[0]") ) { 
    print "ok 32\n" } else {print "not ok 32\n"};


$dbh->Query("create table $tables[0] ( one char(14) primary key,
	two int, three char(1))") or die;

$dbh->Query("insert into $tables[0] (one) values ('jazz')") or die;

@row = $dbh->Query("select * from $tables[0]")->FetchRow();
if (defined $row[0]) {
    print "ok 33\n";
} else {
    print "not ok 33\n";
}

if (defined $row[1]) {
    print "not ok 34\n";
} else {
    print "ok 34\n";
}

if (defined $row[2]) {
    print "not ok 35\n";
} else {
    print "ok 35\n";
}
$dbh->Query("drop table $tables[0]");




