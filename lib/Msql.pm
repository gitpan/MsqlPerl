package Msql;
use vars qw($db_errstr);

require Msql::Statement;
use vars qw($VERSION $QUIET @ISA @EXPORT);
$VERSION = "1.09";
# $Revision: 1.94 $$Date: 1996/07/02 08:25:52 $$RCSfile: Msql.pm,v $

$QUIET = 0;

require Carp;
require AutoLoader;
require DynaLoader;
require Exporter;
@ISA = ('Exporter', 'AutoLoader', 'DynaLoader');
@EXPORT = qw(
        CHAR_TYPE
        INT_TYPE
        REAL_TYPE
);
@EXPORT_OK = qw(
	IDX_TYPE
        chartype
        inttype
        realtype
	idxtype
);

sub CHAR_TYPE { constant("CHAR_TYPE", 0) }
    *chartype = \&CHAR_TYPE;
sub INT_TYPE  { constant("INT_TYPE", 0) }
    *inttype  = \&INT_TYPE;
sub REAL_TYPE { constant("REAL_TYPE", 0) }
    *realtype = \&REAL_TYPE;
sub IDX_TYPE  { constant("IDX_TYPE", 0) }
    *idxtype  = \&IDX_TYPE;
sub host     { return shift->{'HOST'} }
sub sock     { return shift->{'SOCK'} }
sub database { return shift->{'DATABASE'} }

sub AUTOLOAD {
    my $meth = $AUTOLOAD;
    $meth =~ s/^Msql:://;
    $meth =~ s/_//g;
    $meth = lc($meth);

    if (defined &$meth) {
	*$meth = \&{$meth};
	return &$meth(@_);
    }
    Carp::croak "$AUTOLOAD: Not defined in Msql and not autoloadable";
}

bootstrap Msql;

1;
__END__

=head1 NAME

Msql - Perl interface to the mSQL database

=head1 SYNOPSIS

	

  use Msql;
	
  $dbh = Msql->connect;
  $dbh = Msql->connect($host);
  $dbh = Msql->connect($host, $database);
	
  $dbh->selectdb($database);
	
  $sth = $dbh->listfields($table);
  $sth = $dbh->query($sql_statement);
	
  @arr = $dbh->listdbs;
  @arr = $dbh->listtables;
	
  @arr = $sth->fetchrow;
  %hash = $sth->fetchhash;
	
  $sth->dataseek($row_number);

=head1 DESCRIPTION

This package is designed as close as possible to its C API
counterpart. The manual that comes with mSQL describes most things you
need. Due to popular demand it was decided though, that this interface
does not use StudlyCaps (see below).

Internally you are dealing with the two classes C<Msql> and
C<Msql::Statement>. You will never see the latter, because you reach
it through a statement handle returned by a Query or a ListFields
statement. The only class you name explicitly is Msql. It offers you
the connect command:

  $dbh = Msql->connect;
  $dbh = Msql->connect($host);
  $dbh = Msql->connect($host, $database);

This connects you with the desired host/database. With no argument or
with an empty string as the first argument it connects to the UNIX
socket (usually /dev/msql), which has a much better performance than
the TCP counterpart. A database name as the second argument selects
the chosen database within the connection. The return value is a
database handle if the connect succeeds, otherwise the return value is
undef.

You will need this handle to gain further access to the database.

   $dbh->selectdb($database);

If you have not chosen a database with the C<connect> command, or if
you want to change the connection to a different database using a
database handle you have got from a previous C<connect>, then use
selectdb.

  $sth = $dbh->listfields($table);
  $sth = $dbh->query($sql_statement);

These two work rather similar as descibed in the mSQL manual. They return
a statement handle which lets you further explore what the server has
to tell you. On error the return value is undef.

  @arr = $dbh->listdbs();
  @arr = $dbh->listtables;

An array is returned that contains the requested names without any
further information.

  @arr = $sth->fetchrow;

returns an array of the values of the next row fetched from the
server. Similar does

  %hash = $sth->fetchhash;

return a complete hash. The keys in this hash are the column names of
the table, the values are the table values. Be aware, that when you
have a table with two identical column names, you will not be able to
use this method without trashing one column. In such a case, you
should use the fetchrow method.

  $sth->dataseek($row_number);

lets you specify a certain offset of the data associated with the
statement handle. The next fetchrow will then return the appropriate
row (first row being 0).

=head2 No close statement

Whenever the scalar that holds a database or statement handle loses
its value, Msql chooses the appropriate action (frees the result or
closes the database connection). So if you want to free the result or
close the connection, choose to do one of the following:

=over 4

=item undef the handle

=item use the handle for another purpose

=item let the handle run out of scope

=item exit the program.

=back

=head2 Metadata

Now lets reconsider the above methods with regard to metadata.

=head2 Database Handle

As said above you get a database handle with

  $dbh = Msql->connect($host, $database);

The database handle knows about the socket, the host, and the database
it is connected to.

You get at the three values with the methods

  $scalar = $dbh->sock;
  $scalar = $dbh->host;
  $scalar = $dbh->database;

database returns undef, if you have connected without or with only one
argument.

=head2 Statement Handle

Two constructor methods return a statement handle:

  $sth = $dbh->listfields($table);
  $sth = $dbh->query($sql_statement);

$sth knows about all metadata that are provided by the API:

  $scalar = $sth->numrows;    
  $scalar = $sth->numfields;  

  @arr  = $sth->table;       the names of the tables of each column
  @arr  = $sth->name;        the names of the columns
  @arr  = $sth->type;        the type of each column, defined in msql.h
	                     and accessible via Msql::CHAR_TYPE,
	                     &Msql::INT_TYPE, &Msql::REAL_TYPE,
  @arr  = $sth->isnotnull;   array of boolean
  @arr  = $sth->isprikey;    array of boolean
  @arr  = $sth->length;      array of the length of each field in bytes

The six last methods return an array in array context and an array
reference (see L<perlref> and L<perlldsc> for details) when called in
a scalar context. The scalar context is useful, if you need only the
name of one column, e.g.

    $name_of_third_column = $sth->name->[2]

which is equivalent to

    @all_column_names = $sth->name;
    $name_of_third_column = $all_column_names[2];

=head2 @EXPORT

For historical reasons the constants CHAR_TYPE, INT_TYPE, and
REAL_TYPE are in @EXPORT instead of @EXPORT_OK. This means, that you
always have them imported into your namespace. I consider it a bug,
but not such a serious one, that I intend to break old programs by
moving them into EXPORT_OK.

=head2 Connecting to a different port

The mSQL API allows you to interface to a different port than the
default that is compiled into your copy. To use this feature you have
to set the environment variable MSQL_TCP_PORT. You can do so at any
time in your program with the command

    $ENV{'MSQL_TCP_PORT'} = 4333;

Any subsequent connect() will establish a connection to the specified
port.

=head2 Version information

The version of MsqlPerl is always stored in $Msql::VERSION as it is
perl standard. The mSQL API implements methods to access some internal
configuration parameters: gethostinfo, getserverinfo, and
getprotoinfo.  All three are available via a database handle, but are
not associated with the database handle. All three return global
variables that reflect the B<last> connect() command within the
current program.

=head2 Administration

shutdown, creatdb, dropdb, reloadacls are all accessible via a
database handle and implement the corresponding methods to what
msqladmin does.

=head2 The C<-w> switch

With Msql the C<-w> switch is your friend! If you call your perl
program with the C<-w> switch you get the warnings that normally are
stored in $Msql::db_errstr on STDERR. This is a handy method to get
the error messages from the msql server without coding it into your
program. If you want to know in greater detail what's going on, set
the environment variables that are described in David's
manual. David's debugging aid is excellent, there's nothing to be
added.

If you want to use the C<-w> switch but do not want to see the error
messages from the msql daemon, you can set the variable $Msql::QUIET
to some true value, and they will be suppressed.

=head2 StudlyCaps

Real Perl Programmers (C) usually don't like to type I<ListTables> but
prefer I<list_tables> or I<listtables>. The mSQL API uses StudlyCaps
everywhere and so did early versions of MsqlPerl. Beginning with
$VERSION 1.06 all methods are internally in lowercase, but may be
written however you please. Case is ignored and you may use the
underline to improve readability.

The price for using different method names is neglectible. Any method
name you use that can be transformed into a known one, will only be
defined once within a program and will remain an alias until the
program terminates. So feel free to run fetch_row or connecT or
ListDBs as in your old programs. These, of course, will continue to
work.

=head1 PREREQUISITES

mSQL is a libmsql.a library written by David Hughes
L<URL: mailto:bambi@Bond.edu.au>.  You get that at 
L<URL: ftp://Bond.edu.au/pub/Minerva/msql>.

To use the adaptor you definitely have to install this library first.

=head1 AUTHOR

andreas koenig C<koenig@franz.ww.TU-Berlin.DE>

=head1 SEE ALSO

Alligator Descartes wrote a database driver for Tim Bunce's DBI. I
recommend anybody to carefully watch the development of this module
(L<DBI::mSQL>). Msql is a simple, stable, and fast module, and it will
be supported for a long time. But it's a dead end. I expect in the
medium term, that the DBI efforts result in a richer module family
with better support and more functionality. Alligator maintains an
interesting page on the DBI development: http://www.hermetica.com/

=cut


