#!/usr/bin/perl


# Running the testscript with a hostname as $ARGV[0] runs the test via
# a TCP socket. Per default we connect to the unix socket to avoid
# problems you might have with resolving "localhost". Too many systems
# are configured wrong in this respect. But you're welcome to test it
# out.

$host = shift @ARGV || "";

# That's the standard perl way tostart a testscript. It announces that
# that many tests are to follow. And it does so before anything can go
# wrong;

BEGIN { print "1..67\n"; }

use Msql;

package main;

# You may connect in two steps: (1) Connect and (2) SelectDB...

if ($dbh = Msql->connect($host)){
    print "ok 1\n";
} else {
    die "not ok 1: $Msql::db_errstr\n";
}

if ($dbh->selectdb("test")){
    print("ok 2\n");
} else {
    die qq{not ok 2: $Msql::db_errstr
    Please make sure that a database \"test\" exists
    and that you have permission to read and write on it
};
}

# Or you may call connect with two arguments, the first being the
# host, and the second being the DB

if ($dbh = Msql->connect($host,"test")){
    print("ok 3\n");
} else {
    die "not ok 3: $Msql::db_errstr\n";
}

# For the error messages we're going to produce within this script we
# write a subroutine, so the typical error message will always look
# more or less similar:

sub test_error {
    my($id,$query,$error) = @_;
    $id    ||= "?";               # Newer Test::Harness will accept that
    $query ||= "";                # query is optional
    $query = "\n\tquery $query" if $query;
    $error ||= Msql->errmsg;      # without error we ask Msql
    print qq{Not ok $id:\n\terrmsg $error$query\n};
}


# Now we create two tables that are certainly not in the test
# database

# If you haven't seen before, remember this handy method to build a
# hash from an array:

@foundtable  =  $dbh->listtables;
@foundtable{@foundtable} = (1) x @foundtable; # all existing tables are now keys in %foundtable

$goodtable = "TABLE00";
1 while $foundtable{++$goodtable};
$firsttable = $goodtable;
1 while $foundtable{++$goodtable};
$secondtable = $goodtable;

# Always check the return value of any statement! If you use the -w
# switch, you see warnings as they happen, but it's good style to
# check for errors before they happen

my $query = qq{
    create table $firsttable (
			      she char(32),
			      him char(32),
			      who char (32)
			     )
};
$dbh->query($query) or test_error(0,$query,Msql->errmsg);

$query = qq{
    create table $secondtable (
			       she char(32),
			       him char(32) not null,
			       who char (32)
			      )
};
$dbh->query($query) or test_error(0,$query,Msql->errmsg);

# Now we write some test records into the two tables. Note, we *know*,
# these tables are empty

for $query (
	    "insert into $firsttable values ('Anna', 'Franz', 'Otto')"        ,
	    "insert into $firsttable values ('Sabine', 'Thomas', 'Pauline')"  ,
	    "insert into $firsttable values ('Jane', 'Paul', 'Jah')"	      ,
	    "insert into $secondtable values ('Henry', 'Francis', 'James')"   ,
	    "insert into $secondtable values ('Cashrel', 'Beco', 'Lotic')"
	   ) {
    $dbh->query($query) or test_error(0,$query);
}

$sth = $dbh->query("select * from $firsttable") or test_error();

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
while (@row = $sth->fetchrow()){
    $rowcnt++;
}

# We haven't yet tested DataSeek, so lets count again
$sth->dataseek(0);
while (@row = $sth->fetchrow()){
    $rowcnt++;
}

# $rowcount now==6, twice the number of rows we've seen
($rowcnt/2 == $sth->numrows)
    and print ("ok 10\n") or print("not ok 10\n");


# let's see the second table
$sth = $dbh->query("select * from $secondtable") or test_error();

# We set the second field "not null". Does the API know that?
$sth->is_not_null->[1] > 0
    and print ("ok 11\n") or print("not ok 11\n");

# Are we able to just reconnect with the *same* scalar ($dbh) playing
# the role of the db-handle?
if ($dbh = Msql->connect($host,"test")){
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

    $sth1 = $dbh->query("select * from $firsttable")
	or warn "Query had some problem: $Msql::db_errstr\n";
    $sth2 = $dbh->query("select * from $secondtable")
	or warn "Query had some problem: $Msql::db_errstr\n";

    # You have seen this above, so NO COMMENT :)
    $count=0;
    while ($sth2->fetchrow and @row1 = $sth1->fetchrow){
	$count++;
    }
    $count == 2  and print ("ok 13\n") or print("not ok 13\n");

    # When we undef this handle, the memory associated with it is
    # freed
    undef ($sth2);

    $count=0;
    while (@row1 = $sth1->fetchrow){
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
    $sth = $dbh->query  ("select * from $firsttable
	     where him = 'Thomas')");

    # $Msql::db_errstr should contain the word "error" now
    Msql->errmsg =~ /error/
	and print("ok 15\n") or print("not ok 15\n");
}



# Now $sth should be undefined, because the query above failed. If we
# try to use this statementhandle, we should die. We don't want to
# die, because we are in atest script. So we check what happens with
# eval
eval "\@row = \$sth->fetchrow;";
if ($@){print "ok 16\n"} else {print "not ok 16\n"}


# Remember, we inserted a row into table $firsttable ('Sabine',
# 'Thomas', 'Pauline'). Let's see, if they are still there.
$sth = $dbh->query  ("select * from $firsttable
     where him = 'Thomas'")
     or warn "query had some problem: $Msql::db_errstr\n";

@row = $sth->fetchrow or warn "$firsttable didn't find a matching row";
$row[2] eq "Pauline" and print ("ok 17\n") or print("not ok 17\n");

# Isn't it annoing, that we have to remember, which field has which
# name? What if we ever decide to change the table structure? This is
# a simple way to handle your table in the relational way:

# %fieldnum is a hash that associates the index number for each field
# name:
@fieldnum{@{$sth->name}} = 0..@{$sth->name}-1;

# %fieldnum is now (she => 0, him => 1, who => 2)

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
if ($dbh2 = Msql->connect($host,"test")){
    print("ok 19\n");
} else {
    print "not ok 19\n";
}

# Some quick checks about the contents of the handle...
$dbh2->database eq "test" and print("ok 20\n") or print("not ok 20\n");
$dbh2->sock =~ /^\d+$/ and print("ok 21\n") or print("not ok 21\n");

# Is $dbh2 able to drop a table, while we are connected with $dbh?
# Sure it can...
$dbh2->query("drop table $secondtable") and print("ok 22\n") or print("not ok 22\n");


# Does ListDBs find the test database? Sure...
@array = $dbh2->listdbs;
grep( /^test$/, @array ) and print("ok 23\n") or print("not ok 23\n");

# Does ListTables now find our $firsttable?
@array = $dbh2->listtables;
grep( /^$firsttable$/, @array )  and print("ok 24\n") or print("not ok 24\n");


# The third connection within a single script. I promise, this will do...
if ($dbh3 = Connect Msql($host,"test")){
    print("ok 25\n");
} else {
    test_error(25,"connect->$host");
}

$dbh3->host eq $host and print("ok 26\n") or print "not ok 26\n";
$dbh3->database eq "test" and print("ok 27\n") or print "not ok 27\n";


# For what it's worth, we have a tough job for the server here. First
# we define two simple subroutines
sub create {"create table $_[0] ( name char(40) not null,
            num int, country char(4), time real )";}
sub drop {"drop table $_[0]";}

# Then we insert some nonsense changing the dbhandle quickly
$C="AAAA"; $N=1;
$dbh2->query(drop($firsttable)) or test_error(0,drop($firsttable));
$dbh2->query(create($firsttable)) or test_error(0,create($firsttable));

for (1..5){
    $dbh2->query("insert into $firsttable values
	('".$C++."',".$N++.",'".$C++."',".rand().")") or test_error();
    $dbh3->query("insert into $firsttable values
	('".$C++."',".$N++.",'".$C++."',".rand().")") or test_error();
}

# I haven't showed you yet a cute trick to save memory. As query
# returns an object you can reference this object in a single chain of
# -> operators. The statement handle is not preserved, and the memory
# associated with it is cleaned up within a single statement
$dbh2->query("select * from $firsttable")->numrows == 10
    and print("ok 28\n") or print("not ok 28\n");

# Interesting the following test. Creating and dropping of tables via
# two different database handles in quick alteration. There was really
# a version of mSQL that messed up with this
for (1..3){
    $query = drop($firsttable);
    $dbh2->query($query) or test_error(0,$query);
    $query = create($secondtable);
    $dbh2->query($query) or test_error(0,$query);
    $query = drop($secondtable);
    $dbh3->query($query) or test_error(0,$query);
    $query = create($firsttable);
    $dbh3->query($query) or test_error(0,$query);
}
($dbh2->query(&drop($firsttable)) ) and  print("ok 29\n") or print("not ok 29\n");

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
if ( $dbh2->query("create table $firsttable (FOO int)") ) {
    print "ok 31\n" } else {print "not ok 31\n"};
if ( $dbh2->query("drop table $firsttable") ) {
    print "ok 32\n" } else {print "not ok 32\n"};


# The following tests show, that NULL fields (introduced with
# msql-1.0.6) are handled correctly:
if (Msql->getserverinfo lt 2) { # Before version 2 we have the "primary key" syntax
    $dbh->query("create table $firsttable ( she char(14) primary key,
	him int, who char(1))") or test_error();
} else {
    $dbh->query("create table $firsttable ( she char(14),
	him int, who char(1))") or test_error();
    $dbh->query("create unique index Xperl1 on $firsttable ( she )") or test_error();
}

# As you see, we don't insert a value for "him" and "who", so we can
# test the undefinedness
$dbh->query("insert into $firsttable (she) values ('jazz')") or test_error;

$sth = $dbh->query("select * from $firsttable") or test_error;
@row = $sth->fetchrow() or test_error;

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

# field "who", an integer field, should not be defined
if (defined $row[2]) {
    print "not ok 35\n";
} else {
    print "ok 35\n";
}

# So far we have evaluated metadata in scalar context. Let's see,
# if array context works
$i = 35;
foreach (qw/table name type is_not_null is_pri_key length/) {
    my @arr = $sth->$_();
    if (@arr == 3){
	print "ok ", ++$i, "\n";
    } else {
	print "not ok ", ++$i, ": @arr\n";
    }
}

# A non-select should return TRUE, and if anybody tries to use this
# return value as an object reference, we should not core dump
$sth = $dbh->query("insert into $firsttable values (\047x\047,2,\047y\047)");
eval {$sth->fetchrow;};
if ($@ =~ /^Can\'t call method/) {
    print "ok 42\n";
}

# So many people have problems using the ListFields method,
# so we finally provide a simple example.
$sth_query = $dbh->query("select * from $firsttable");
$sth_listf = $dbh->listfields($firsttable);
$i = 43;
for $method (qw/name table length type is_not_null is_pri_key/) {
    for (0..$sth_query->numfields -1) {
	# whatever we do to the one statementhandle, the other one has
	# to behave exactly the same way
	if ($sth_query->$method()->[$_] eq $sth_listf->$method()->[$_]) {
	    print "ok $i\n" ;
	} else {
	    print "not ok $i\n";
	}
	$i++;
    }
}

# The only difference: the ListFields sth must not have a row associated with
if ($sth_listf->numrows == 0) {
    print "ok 61\n";
} else {
    print "not ok 61\n";
}
if ($sth_query->numrows > 0) {
    print "ok 62\n";
} else {
    print "not ok 62\n";
}

# Please understand that features that were added later to the module
# are tested later. Here's a very nice test. Should be easier to
# understand than the others:

$sth_query->dataseek(0);
$i = 63;
while (%hash = $sth_query->fetchhash) {

    # fetchhash stuffs the contents of the row directly into a hash
    # instead of a row. We have only two lines to check. Column she
    # has to be either 'jazz' or 'x'.
    if ($hash{she} eq 'jazz' or $hash{she} eq 'x') {
	print "ok $i\n";
    } else {
	print "not ok $i\n";
    }
    $i++;
}


$dbh->query("drop table $firsttable") or test_error;

# Although it is a bad idea to specify constants in lowercase,
# I have to test if it is supported as it has been documented:

if (Msql::int___type() == INT_TYPE) {
    print "ok 65\n";
} else {
    print "not ok 65\n";
}


# Let's create another table where we inspect if we can insert
# 8 bit characters:

$query = "create table $firsttable (ascii int, character char(1))";
$dbh->query($query) or test_error;
for (1..255) {
    my $chr = $dbh->quote(chr($_));
    my $query = qq{
	insert into $firsttable values ($_, $chr)
    };
    $dbh->query($query) or print "not ok 66\n"; # well, could happen more thn once, but ...
}
$sth = $dbh->query("select * from $firsttable") or test_error;
if ($sth->numrows() == 255){
    print "ok 66\n";
} else {
    print "not ok 66\n";
}
while (%hash = $sth->fetchhash) {
    $hash{character} eq chr($hash{ascii}) or print "not ok 67 [char no $hash{ascii}]\n";
}
print "ok 67\n";

$dbh->query("drop table $firsttable") or test_error;

