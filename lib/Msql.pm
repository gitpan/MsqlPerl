package Msql;

require Msql::Statement;

$VERSION = $VERSION = "1.02";
# $Revision: 1.87 $$Date: 1995/08/20 10:52:39 $$RCSfile: Msql.pm,v $

$QUIET = $QUIET = 0;

require Carp;
require AutoLoader;
require DynaLoader;
require Exporter;
@ISA = ('Exporter', 'AutoLoader', 'DynaLoader');
@EXPORT = qw(
        &CHAR_TYPE
        &INT_TYPE
        &REAL_TYPE
);


sub AUTOLOAD {
    if (
	$AUTOLOAD eq 'Msql::CHAR_TYPE' ||
	$AUTOLOAD eq 'Msql::INT_TYPE' ||
	$AUTOLOAD eq 'Msql::REAL_TYPE'
       ) {
	local($constname);
	($constname = $AUTOLOAD) =~ s/.*:://;
	$val = constant($constname, @_ ? $_[0] : 0);
	if ($! != 0) {
	    if ($! =~ /Invalid/) {
		$AutoLoader::AUTOLOAD = $AUTOLOAD;
		goto &AutoLoader::AUTOLOAD;
	    }
	    else {
		Carp::croak("Not defined Msql macro $constname");
	    }
	}
	eval "sub $AUTOLOAD { $val }";
	goto &$AUTOLOAD;
    } elsif (
	$AUTOLOAD eq 'Msql::host' ||
	$AUTOLOAD eq 'Msql::database' ||
	$AUTOLOAD eq 'Msql::sock'
	   ) {
	$AUTOLOAD =~ s/.*://;
	my $auto = uc $AUTOLOAD;
	eval "sub $AUTOLOAD {return shift->{$auto};}";
	goto &$AUTOLOAD;
    } else {
	Carp::croak("$AUTOLOAD: Not defined in Msql");
    }
}

bootstrap Msql;

# Preloaded methods go here.  Autoload methods go after __END__, and are
# processed by the autosplit program.

# The following lines were testing code for a Tie'd interface.
# But it was rather slow.
# Outcommented in case somebody would like to implement anything Tie'd
#package Msql;

#sub TieQuery {
#    require Msql::Tie;
#    package Msql::Statement;
#    use Carp;
#    my($self,$query) = @_;
#    my %hash;
#    my $sth = $self->FastQuery($query) or return carp("Unsuccessful Query");
#    tie %hash, Msql::Tie;
#    $hash{MYTIE}=$sth;
#    bless \%hash;
#}

#sub TieListFields {
#    require Msql::Tie;
#    package Msql::Statement;
#    use Carp;
#    my($self,$query) = @_;
#    my %hash;
#    my $sth = $self->FastListFields($query) or return carp("Unsuccessful ListFields");
#    tie %hash, Msql::Tie;
#    $hash{MYTIE}=$sth;
#    bless \%hash;
#}

package Msql;

1;
__END__

=head1 NAME

The Msql Perl Adaptor: Simple Perl interface to the mSQL database

=head1 SYNOPSIS

	

  use Msql;
	
  $dbh = Connect Msql;
  $dbh = Connect Msql $host;
  $dbh = Connect Msql $host, $database;
	
  SelectDB           $dbh $database;
	
  $sth = ListFields  $dbh $table;
  $sth = Query       $dbh $sql_statement;
	
  @arr = ListDBs     $dbh;
  @arr = ListTables  $dbh;
	
  @arr = FetchRow    $sth;
	
  DataSeek           $sth $row_number;

=head1 DESCRIPTION

This package is designed as close as possible to its C API
counterpart. The manual that comes with mSQL describes most things you
need. 

Internally you are dealing with the two classes C<Msql> and
C<Msql::Statement>. You will never see the latter, because you reach
it through a statement handle returned by a Query or a ListFields
statement. The only class you name explicitly is Msql. It offers you
the Connect command:

  $dbh = Connect Msql;
  $dbh = Connect Msql $host;
  $dbh = Connect Msql $host, $database;

This connects you with the desired host/database. With no argument or
with an empty string as the first argument it connects to the UNIX
socket /dev/msql, which is a big performance gain. A database name as
the second argument selects the chosen database within the
connection. The return value is a database handle if the Connect
succeeds, otherwise the return value is undef.

You will need this handle to gain further access to the
database. Issue multiple C<Connect> statements -- no problem.

  SelectDB $dbh $database;

If you have not chosen a database with the C<Connect> command, or if
you want to change the connection to a different database using a
database handle you have got from a previous C<Connect>, then use
SelectDB.

  $sth = ListFields  $dbh $table;
  $sth = Query       $dbh $sql_statement;

These two work rather similar as descibed in the mSQL manual. They return
a statement handle which lets you further explore what the server has
to tell you. On error the return value is undef.

  @arr = ListDBs     $dbh;
  @arr = ListTables  $dbh;

An array is returned that contains the requested names without any
further information.

  @arr = FetchRow   $sth;

returns an array of the values of the next row fetched from the
server.

  DataSeek          $sth  $row_number;

lets you specify a certain offset of the data associated with the
statement handle. The next FetchRow will then return the appropriate
row (first row being 0).

=head2 No close statement

Whenever the scalar that holds a database or statement handle looses
its value, Msql chooses the appropriate action (frees the result or
closes the database connection). So if you want to free the result or
close the connection, choose to do one of the following:

=over 4

=item undef the handle

=item use the handle for another purpose

=item use the handle inside a block and declare it with my()

=item exit the program.

=back

=head1 Metadata

Now lets reconsider the above methods with regard to metadata.

=head2 Database Handle

As said above you get a database handle with

  $dbh = Connect Msql $host, $database;

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

  $sth = ListFields  $dbh $table;
  $sth = Query       $dbh $sql_statement;

$sth knows about all metadata that are provided by the API:

  $scalar = $sth->numrows;    
  $scalar = $sth->numfields;  
  $arrref  = $sth->table;       the names of the tables of each column
  $arrref  = $sth->name;        the names of the columns
  $arrref  = $sth->type;        the type of each column, defined in msql.h
		                and accessible via &Msql::CHAR_TYPE,
		                &Msql::INT_TYPE, &Msql::REAL_TYPE,
  $arrref  = $sth->is_not_null; array of boolean
  $arrref  = $sth->is_pri_key;  array of boolean
  $arrref  = $sth->length;      array of the length of each field in bytes


=head2 The C<-w> switch

Also with Msql the -w switch is your friend! If you call your perl
program with the -w switch you get the warnings that normally are
stored in $Msql::db_errstr on STDERR. This is a handy method to get
the error messages from the msql server without coding it into your
program. If you want to know in greater detail what's going on, set
the environment variables that are described in David's
manual. David's debugging aid is excellent, there's nothing to be
added.

If you want to use the -w switch but do not want to see the error
messages from the msql daemon, you can set the variable $Msql::QUIET
to some true value, and they will be suppressed.

=head1 PREREQUISITES

mSQL is a libmsql.a library written by David Hughes
L<bambi@Bond.edu.au>.  You get that stuff at 
L<URL: ftp://Bond.edu.au/pub/Minerva/msql>.

To use the adaptor you definitely have to install this library first.

=head1 AUTHOR

andreas koenig L<koenig@franz.ww.TU-Berlin.DE>


=head1 BUGS

Msql does not support Tim Bunce's Database Interface DBI (yet :')

=cut


