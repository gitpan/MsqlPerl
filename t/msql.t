#!/usr/bin/perl


# Running the testscript with a hostname as $ARGV[0] runs the test via
# a TCP socket. Per default we connect to the unix socket to avoid
# problems you might have with resolving "localhost". Too many systems
# are configured wrong in this respect. But you're welcome to test it
# out.
$host = shift || "";

# That's the standard perl way tostart a testscript. It announces that
# so many tests follow
print "1..35\n";

use Msql;

package main;

#You may connect in two steps: (1) Connect and (2) SelectDB...

if ($dbh = Msql->Connect($host)){
    print "ok 1\n";
} else {
    die "not ok 1: $Msql::db_errstr\n";
}

if ($dbh->SelectDB("test")){ 
    print("ok 2\n");
} else {
    die "not ok 2: $Msql::db_errstr
Please make sure that a database \"test\" exists
and that you can read and write on it
";
}

# Or you may call connect with two arguments, the first being the
# host, and the second being the DB

if ($dbh = Msql->Connect($host,"test")){
    print("ok 3\n");
} else {
    die "not ok 3: $Msql::db_errstr\n";
}

#First we create two tables that are certainly not in the test
#database

@foundtable  =  $dbh->ListTables;
@foundtable{@foundtable} = (1) x @foundtable;

$goodtable = "TABLE00";
1 while $foundtable{++$goodtable};
$firsttable = $goodtable;
1 while $foundtable{++$goodtable};
$secondtable = $goodtable;

# Always check the return value of any statement! If you use the -w
# switch, you see warnings as they happen, but it's good style to
# check for errors before they happen
$dbh->Query("create table $firsttable (she char(32), him char(32),
  three char (32))") or die $Msql::db_errstr;

$dbh->Query("create table $secondtable (she char(32),
  him char(32) not null, three char (32))") or die $Msql::db_errstr;

# Now we write some test records into the two tables. Note, we *know*,
# these tables are empty

$dbh->Query("insert into $firsttable values ('Anna', 'Franz', 'Otto')") or die $Msql::db_errstr;
$dbh->Query("insert into $firsttable values ('Sabine', 'Thomas', 'Pauline')") or die $Msql::db_errstr;
$dbh->Query("insert into $firsttable values ('Jane', 'Paul', 'Jah')") or die $Msql::db_errstr;
$dbh->Query("insert into $secondtable values ('Henry', 'Francis', 'James')") or die $Msql::db_errstr;
$dbh->Query("insert into $secondtable values ('Cashrel', 'Beco', 'Lotic')") or die $Msql::db_errstr;


$sth = $dbh->Query("select * from $firsttable") or die $Msql::db_errstr;

($sth->numrows == 3)   and print("ok 4\n") or print("not ok 4\n"); # three rows
($sth->numfields == 3) and print("ok 5\n") or print("not ok 5\n"); # three columns

# There is the array reference $sth->name. It has to have as many
# fields as $sth->numfields tells us
(@{$sth->name} == $sth->numfields) 
    and print ("ok 6\n") or print("not ok 6\n");

# There is the array reference $sth->table. We expect, that all three
# fields in the array have the same value, as we only selected from
# $firsttable
$sth->table->[0] eq $firsttable
    and print ("ok 7\n") or print("not ok 7\n");
$sth->table->[1] eq $sth->table->[2] 
    and print ("ok 8\n") or print("not ok 8\n");

# CHAR_TYPE, NUM_TYPE and REAL_TYPE are exported functions from
# Msql. That is why you have to say 'use Msql'. The functions are
# really constants, but that's the way headerfile constants are
# handled in perl5 up to 5.001m (will probably change soon)
CHAR_TYPE() == $sth->type->[0] 
    and print ("ok 9\n") or print("not ok 9\n");

# Now we count the rows ourselves, we don't trust anybody
$rowcnt=0;
while (@row = $sth->FetchRow()){
    $rowcnt++;
}

# We haven't yet tested DataSeek, so lets count again
$sth->DataSeek(0);
while (@row = $sth->FetchRow()){
    $rowcnt++;
}

# $rowcount now==6, twice the number of rows we've seen
($rowcnt/2 == $sth->numrows)
    and print ("ok 10\n") or print("not ok 10\n");


# let's see the second table
$sth = $dbh->Query("select * from $secondtable") or die $Msql::db_errstr;

# We set the second field "not null". Does the API know that?
$sth->is_not_null->[1] > 0 
    and print ("ok 11\n") or print("not ok 11\n");

# Are we able to just reconnect with the *same* scalar ($dbh) playing
# the role of the db-handle?
if ($dbh = Msql->Connect($host,"test")){
    print("ok 12\n");
} else {
    print "not ok 12: $Msql::db_errstr\n";
}

# We may have an arbitrary number of statementhandles. Each
# statementhandle consumes memory, so in reality we try to scope them
# with my() within a block or we reuse them or we undef them.
{
    # Declare the statement handle as lexically scoped (see man
    # perlfunc and search for 'my EXPR') Don't forget to scope other
    # variables too, that you won't need outside the block
    my($sth1,$sth2,@row1,$count);

    $sth1 = $dbh->Query("select * from $firsttable")
	or warn "Query had some problem: $Msql::db_errstr\n";
    $sth2 = $dbh->Query("select * from $secondtable")
	or warn "Query had some problem: $Msql::db_errstr\n";

    # You have seen this above, so NO COMMENT :)
    $count=0;
    while ($sth2->FetchRow and @row1 = $sth1->FetchRow){
	$count++;
    }
    $count == 2  and print ("ok 13\n") or print("not ok 13\n"); 

    # When we undef this handle, the memory associated with it is
    # freed
    undef ($sth2);

    $count=0;
    while (@row1 = $sth1->FetchRow){
	$count++;
    }
    $count == 1 and print ("ok 14\n") or print("not ok 14\n");

    # When we leave this block, the memory associated with $sth1 is
    # freed
}

# What happens, when we have errors?
# Yes, there's a typo: we add a paren to the statement
{
    # The use of the -w switch is really a good idea in general, but
    # if you want the -w switch but do NOT want to see Msql's error
    # messages, you can turn them off using $Msql::QUIET

    local($Msql::QUIET) = 1;
    # In reality we would say "or die ...", but in this case we forgot it:
    $sth = $dbh->Query  ("select * from $firsttable
	     where him = 'Thomas')");

    # $Msql::db_errstr should contain the word "error" now
    $Msql::db_errstr =~ /error/
	and print("ok 15\n") or print("not ok 15\n");
}



# Now $sth should be undefined, because the query above failed. If we
# try to use this statementhandle, we should die. We don't want to
# die, because we are in atest script. So we check what happens with
# eval
eval "\@row = \$sth->FetchRow;";
if ($@){print "ok 16\n"} else {print "not ok 16\n"}


# Remember, we inserted a row into table $firsttable ('Sabine',
# 'Thomas', 'Pauline'). Let's see, if they are still there.
$sth = $dbh->Query  ("select * from $firsttable
     where him = 'Thomas'")
     or warn "Query had some problem: $Msql::db_errstr\n";

@row = $sth->FetchRow or warn "$firsttable didn't find a matching row";
$row[2] eq "Pauline" and print ("ok 17\n") or print("not ok 17\n");

# Isn't it annoing, that we have to remember, which field has which
# name? What if we ever decide to change the table structure? This is
# a simple way to handle your table in the relational way:

# %fieldnum is a hash that associates the index number for each field
# name:
@fieldnum{@{$sth->name}} = 0..@{$sth->name}-1;

# %fieldnum is now (she => 0, him => 1, three => 2)

# So we do not have to hard-code the zero for "she" here
$row[$fieldnum{"she"}] eq 'Sabine' 
    and print ("ok 18\n") or print("not ok 18\n");


# After 18 tests, the database handle may feel the desire to rest. Or
# maybe the writer of this script has forgotten, that he is already
# connected

# While in reality you should use your database connections
# economically -- they cost you a slot in the server connection table,
# and you can easily run out of available slots -- we, in the test
# script want to know what happens with more than one handle
if ($dbh2 = Msql->Connect($host,"test")){
    print("ok 19\n");
} else {
    print "not ok 19\n";
}

# Some quick checks about the contents of the handle...
$dbh2->database eq "test" and print("ok 20\n") or print("not ok 20\n");
$dbh2->sock =~ /^\d+$/ and print("ok 21\n") or print("not ok 21\n");

# Is $dbh2 able to drop a table, while we are connected with $dbh?
# Sure it can...
$dbh2->Query("drop table $secondtable") and print("ok 22\n") or print("not ok 22\n");


# Does ListDBs find the test database? Sure...
@array = $dbh2->ListDBs;
grep( /^test$/, @array ) and print("ok 23\n") or print("not ok 23\n");

# Does ListTables now find our $firsttable?
@array = $dbh2->ListTables;
grep( /^$firsttable$/, @array )  and print("ok 24\n") or print("not ok 24\n");


# The third connection within a single script. I promise, this will do...
if ($dbh3 = Connect Msql($host,"test")){
    print("ok 25\n");
} else {
    die "not ok 25\n";
}

$dbh3->host eq $host and print("ok 26\n") or die "not ok 26\n";
$dbh3->database eq "test" and print("ok 27\n") or die "not ok 27\n";


# For what it's worth, we have a tough job for the server here. First
# we define two simple subroutines
sub create {"create table $_[0] ( name char(40) not null, 
            num int primary key, country char(4), time real )";}
sub drop {"drop table $_[0]";}

# Then we insert some nonsense changing the dbhandle quickly
$C="AAAA"; $N=1;
$dbh2->Query(drop($firsttable)) or die "Couldn't create: $Msql::db_errstr\n";
$dbh2->Query(create($firsttable)) or die "Couldn't create: $Msql::db_errstr\n";
for (1..5){
    $dbh2->Query("insert into $firsttable values 
	('".$C++."',".$N++.",'".$C++."',".rand().")") or die $Msql::db_errstr;
    $dbh3->Query("insert into $firsttable values
	('".$C++."',".$N++.",'".$C++."',".rand().")") or die $Msql::db_errstr;
}

# I haven't showed you yet a cute trick to save memory. As Query
# returns an object you can reference this object in a single chain of
# -> operators. The statement handle is not preserved, and the memory
# associated with it is cleaned up within a single statement
$dbh2->Query("select * from $firsttable")->numrows == 10
    and print("ok 28\n") or print("not ok 28\n");

# Interesting the following test. Creating and dropping of tables via
# two different database handles in quick alteration. There was really
# a version of mSQL that messed up with this
for (1..3){
    $dbh2->Query(&drop($firsttable)) or die $Msql::db_errstr;
    $dbh2->Query(&create($secondtable)) or die $Msql::db_errstr;
    $dbh3->Query(&drop($secondtable)) or die $Msql::db_errstr;
    $dbh3->Query(&create($firsttable)) or die $Msql::db_errstr;
}
($dbh2->Query(&drop($firsttable)) ) and  print("ok 29\n") or print("not ok 29\n");

# A quick check, if the array @{$sth->length} is available and
# correct. See man perlref for an explanation of this kind of
# referencing/dereferencing. Watch out, that we still use an old
# statement handle here. The corresponding table has been overwritten
# quite a few times, but as we are dealing with a in-memeory copy, we
# still have it available
if ("@{$sth->length}" eq "32 32 32"){
    print "ok 30\n";
} else {
    print "not ok 30\n";
}


# These tests are quite redundant, left-over from an older version of this script
if ( $dbh2->Query("create table $firsttable (FOO int)") ) { 
    print "ok 31\n" } else {print "not ok 31\n"};
if ( $dbh2->Query("drop table $firsttable") ) { 
    print "ok 32\n" } else {print "not ok 32\n"};


# The following tests show, that NULL fields (introduced with
# msql-1.0.6) are handled correctly:
$dbh->Query("create table $firsttable ( she char(14) primary key,
	him int, three char(1))") or die;

# As you see, we don't insert a value for "him" and "three"
$dbh->Query("insert into $firsttable (she) values ('jazz')") or die;

# You have seen this kind of chaining above. As I'm absolutely sure,
# there will be returned only one row, I do it again
@row = $dbh->Query("select * from $firsttable")->FetchRow() or die $Msql::db_errstr;

# "she" is "jazz", thusly defined
if (defined $row[0]) {
    print "ok 33\n";
} else {
    print "not ok 33\n";
}

# field "him", a character field, should not be defined
if (defined $row[1]) {
    print "not ok 34\n";
} else {
    print "ok 34\n";
}

# field "three", an integer field, should not be defined
if (defined $row[2]) {
    print "not ok 35\n";
} else {
    print "ok 35\n";
}

$dbh->Query("drop table $firsttable") or die $Msql::db_errstr;




