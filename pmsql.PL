use Config;
use File::Basename qw(&basename &dirname);
# This forces PL files to create target in same directory as PL file.
# This is so that make depend always knows where to find PL derivatives.
chdir(dirname($0));
($file = basename($0)) =~ s/\.PL$//;
$file =~ s/\.pl$//
	if ($Config{osname} eq 'VMS' or $Config{osname} eq 'os2');  # "case-forgiving"

open OUT,">$file" or die "Can't create $file: $!";

print "Extracting $file (with variable substitutions)\n";



#
# Start of pmsql
#

print OUT <<"!GROK!THIS!";
$Config{'startperl'}
!GROK!THIS!
print OUT <<'!NO!SUBS!';

# $Id: pmsql.PL,v 1.24 1996/06/29 12:49:38 k Exp $
my $version = substr q$Revision: 1.24 $, 10;

BEGIN {require 5.002;}
# use strict;      # only for testing. Unfriendly for the user-eval()s
# $^W = 1;         # too early for readline 0.8
use Msql ();
use Term::ReadLine;
use Carp ();

# term

my $term = new Term::ReadLine 'MsqlPerl Monitor';

# prompt

my $prompt = "pmsql> ";
$readline::rl_completion_function = 'main::complete';

$^W = 1;
# $SIG{'__WARN__'} = sub { warn Carp::longmess(@_); };

# typelabels

my(@typelabel);
@typelabel[Msql::chartype(),Msql::inttype(),Msql::realtype(),Msql::idxtype()] = qw(char int real index);

# host

my $host = "";
if (@ARGV && $ARGV[0] eq "-h") {
    shift;
    $host = shift or die usage();
}

# Less

my $Less;
{
    my @path = split ":", $ENV{PATH};
    $Less = $ENV{PMSQL_PAGER} || $ENV{PAGER} || find_exe("less",[@path]) || 
                find_exe("more",[@path]) || "";
}

# database

my $database = $ARGV[0];

{
    my $rl_avail = defined &Term::ReadLine::Perl::readline ? "enabled" : "available (get Term::ReadKey and Term::ReadLine::Perl)";

    print qq{
pmsql -- interactive mSQL monitor version $version
Readline support $rl_avail

};
}

#
# Formatting of the tables
#

$Msql::Statement::Optimize_Table=1;



while ( defined ($_ = $term->readline($prompt)) ) {

    #
    # Let them eval a piece of perl
    #

    if (/^\!/) {
	$term->addhistory($_) if /\S/;
	s/^\!//;
	eval($_);
	warn $@ if $@;
	print "\n";
	next;

    #
    # Give some advice
    #

    } elsif (/^\?/) {
	print qq{
ho[st] <host>                            Set default host (current is "$host")
da[tabase] <database>                    Set default database (current is "$database")
re[lshow] [-h host] [database] [table]   describe databases or tables and
                                                  set default host and database
! <anything>                             eval string in perl
?                                        print this message
q[uit]                                   leave pmsql
<anything else>                          query default database on default host

};
	next;
    }

    #
    # Look closer what they said
    #

    my($command,@arg) = /^\s*(\S+)\s*(\S*)\s*(\S*)/;
    next unless defined $command;

    if ($command =~ /^ho(s(t)?)?$/i) {

	# HOST

	$host = $arg[0];
	print qq{Host set to "$host"\n};
    } elsif ($command =~ /^da(t(a(b(a(s(e)?)?)?)?)?)?$/i) {

	# DATABASE

	$database = $arg[0] if $arg[0] gt "";
	print qq{Database set to "$database"\n};
    } elsif ($command =~ /^re(l(s(h(o(w)?)?)?)?)?$/i) {

	# RELSHOW

	print relshow(@arg);
    } elsif ($command =~ /^q(u(i(t)?)?)?$/i) {

	# QUIT

	print "Goodbye\n";
	last;
    } else {

	# This is a query

	unless ($database) {
	    print "No default database defined\n";
	    next;
	}
	my $Db = Msql->Connect($host,$database) or next;
	s/\\[qgp]$//;
	$::Q = $Db->Query($_) or next;
	print "Query ok\n";
	if (ref $::Q) {
	    if ($Less) {
		open OUT, "| $Less";
	    } else {
		open OUT, ">&STDOUT";
	    }
	    print OUT $::Q->as_string;
	    close OUT;
	}
    }
}

exit;

package Msql::Statement;
use vars qw($Optimize_Table);

sub unctrl {
    my($x) = @_;
    $x =~ s/\\/\\\\/g;
    $x =~ s/([\001-\037\177])/sprintf("\\%03d",unpack("C",$1))/eg;
    $x;
}

sub as_string {
    my($sth) = @_;
    my($plusline,$titline,$sprintf,$result,$s) = ('+','|','|');
    if ($Optimize_Table) {
	my(@sprintf,$l);
	for (0..$sth->numfields-1) {
	    $sprintf[$_] = length($sth->name->[$_]);
	}
	$sth->DataSeek(0);
	my(@row);
	while (@row = map {defined $_ ? unctrl($_) : "NULL"} $sth->FetchRow) {
	    foreach (0..$#row) {
		$sprintf[$_] = length($row[$_]) if length($row[$_]) > $sprintf[$_];
	    }
	}
	for (0..$sth->numfields-1) {
	    $l = $sprintf[$_];
	    $l *= -1 if 
		$sth->type->[$_] == Msql::CHAR_TYPE();
	    $plusline .= sprintf "%$ {l}s+", "-" x $sprintf[$_];
	    $titline .= sprintf "%$ {l}s|", $sth->name->[$_];
	    $sprintf .= "%$ {l}s|";
	}
    } else {
	for (0..$sth->numfields-1) {
	    my $l;
	    if ($sth->type->[$_] == Msql::INT_TYPE()){
		$l = 10;
	    } elsif ($sth->type->[$_] == Msql::REAL_TYPE()){
		$l = 16;
	    } else {
		$l = $sth->length->[$_];
	    }
	    $l < length($sth->name->[$_]) and $l = length($sth->name->[$_]);
	    $plusline .= "-" x $l . "+";
	    $titline .= $sth->name->[$_] . " " x ($l - length($sth->name->[$_])) . "|";
	    $sprintf .= $sth->type->[$_] == Msql::CHAR_TYPE() ? "%-$ {l}s|" : "%$ {l}s|";
	}
    }
    $sprintf .= "\n";
    #WHY?: print $@ if $@;
    $result = "$plusline\n$titline\n$plusline\n";
    $sth->DataSeek(0);
    my(@row);
    while (@row = map {defined $_ ? unctrl($_) : "NULL"} $sth->FetchRow) {
	$result .= sprintf $sprintf, @row;
    }
    $result .= "$plusline\n";
    $s = $sth->numrows == 1 ? "" : "s";
    $result .= $sth->numrows . " row$s processed\n\n";
    return $result;
}


package main;

sub complete {
    my($word,$line,$pos) = @_;
    $word ||= "";
    $line ||= "";
    $pos ||= 0;
    #print STDERR join " ** ", ("|",$word,$line,$pos,"|");
    $line =~ s/^\s*//;
    return
	$pos == 0 ? grep /^$word/i, ('!','?','create table','database','delete from','drop table','host','insert into','quit','relshow','select','update') :
	$line =~ /^[\!\?qch]/i ? () :
	$line =~ /^da/i ? complete_database($word) :
	$line =~ /^de/i ? complete_table_or_field($word,$line) :
	$line =~ /^dr/i ? complete_table($word,$line) :
	$line =~ /^in/i ? complete_table_or_field($word,$line) :
	$line =~ /^re/i ? complete_table_or_field($word,$line) :
	$line =~ /^se/i ? complete_table_or_field($word,$line) :
	$line =~ /^up/i ? complete_table_or_field($word,$line) : ();
}

sub complete_database {
    my($word) = shift;
    grep /^\Q$word/, Msql->connect($host)->listdbs;
}

sub complete_table {
    my($word,$line) = @_;
    my($db) = $line =~ /^r\w+\s+(\w+)/;
    #print STDERR "line [$line] db [$db]";
    $db ||= $database;
    return () unless $db;
    grep /^\Q$word/, Msql->connect($host, $db)->listtables;
}

sub complete_table_or_field {
    my($word,$line) = @_;
    return complete_database($word) if $line =~ /^r\w+\s+\Q$word\E$/;
    return complete_table($word,$line) if 
	$line =~ /^[ds].*\sfrom\s+\Q$word\E$/ ||	# delete, select
	$line =~ /^u\w+\s+\Q$word\E$/ || # update
	$line =~ /^r\w+\s+\w+\s+\Q$word\E$/ || # relshow
	$line =~ /^i.*\sinto\s+\Q$word\E$/ # insert
	    ;
    return () unless $database;
    my ($table) = $1 if
	$line =~ /^[ds].*\sfrom\s+(\w+)/ ||	# delete, select
	$line =~ /^u\w+\s+(\w+)/ || # update
	$line =~ /^r\w+\s+\w+\s+(\w+)/ || # relshow
	$line =~ /^i.*\sinto\s+(\w+)/ # insert
	;
    my(@table) = $table ? ($table) : Msql->connect($host, $database)->listtables;
    my($db,%fields,@fields) = Msql->connect($host, $database);
    for $table (@table) {
	@fields = $db->listfields($table)->name;
	@fields{@fields} = (1) x @fields;
    }
    return sort grep /^\Q$word/, keys %fields;
}

sub find_exe {
    my($exe,$path) = @_;
    my($dir);
    for $dir (@$path) {
        my $abs = "$dir/$exe";
        if (-x $abs) {
            return $abs;
        }
    }
}

sub longest {
    my $l = 0;
    for (@_) {
	$l=length if length > $l
    }
    $l;
}

sub relshow {
    if (@_ && $_[0] eq "-h") {
	shift @_;
	$host = shift @_ or die usage();
    }

    if (@_ > 2){
	return "Usage: relshow [-h host] [database] [table]\n";
    }

    my @m;

    push @m, "Host = $host\n" if $host;
    my $Dbh = Msql->Connect($host) or return;

    my($table,$bottok,$sorry,$i);

    if ($_[0]) {
	$database = shift @_;
	return "Couldn't connect to $database\n" unless $Dbh->SelectDB($database);
	push @m, "\nDatabase = $database\n";
	if ($table = shift @_) {
	    #
	    # relshow database table
	    #

	    grep /^\Q$table\E$/, $Dbh->ListTables or return join "", @m, qq{Table "$table" not found\n};
	    my $sth = $Dbh->ListFields($table) or return join "", @m, qq{Error reading listfields($table)\n};
	    my $fieldwidth = longest($sth->name,"Field") || 15;
	    my $border = " +-".("-"x$fieldwidth)."-+------+--------+----------+-----+\n";
	    push @m, qq{Table = $table\n};
	    push @m, $border;
	    push @m, sprintf " | %-".$fieldwidth."s | Type | Length | Not Null | Key |\n", "Field";
	    push @m, $border;
	    my $max = $sth->numfields;
	    for ($i=0;$i<$max;$i++){
		push @m, sprintf " | %-".$fieldwidth."s | %-4s | %6s |     %-2s   |  %-2s |\n",
			$sth->name->[$i],
			$typelabel[$sth->type->[$i]] || ("unknown-".$sth->type->[$i]),
			$sth->length->[$i],
			$sth->is_not_null->[$i] ? "Y" : "N",
			$sth->is_pri_key->[$i] ? "Y" : "N";
	    }
	    push @m, "$border\n";
	} else {
	    #
	    # relshow database
	    #

	    my @l = $Dbh->ListTables;
	    if (@l) {
		my $border = "  +---------------------+\n";
		push @m, qq{
$border  |       Table         |\n$border};
		my $elem;
		for $elem (@l) {
		    push @m, sprintf "  | %-19s |\n", $elem;
		}
		push @m, "$border\n";
	    } else {
		push @m, "No tables in database\n";
	    }
	}
    } else {
	#
	# relshow
	#

	my @l = $Dbh->ListDBs;
	if (@l) {
	    my $border = "  +------------------+\n";
	    push @m, qq{
$border  |    Databases     |\n$border} ;
	    my $elem;
	    for $elem (@l) {
		push @m, sprintf "  | %-16s |\n", $elem;
	    }
	    push @m, "$border\n";
	} else {
	    push @m, "No databases found\n";
	}
    }
    return join "", @m;
}

sub usage () {"Usage: $0 [-h host] database";}

__END__

=head1 NAME

pmsql - interactive shell with readline for msql

=head1 SYNOPSIS

C<pmsql [-h host] [database]>

=head1 DESCRIPTION

pmsql lets you talk to a running msql daemon sending either SQL
queries or relshow commands. The output is formatted much in the same
way as by the msql monitor (see below) and the relshow program, which
are both coming with msql. The additional capability is a connection
to a readline interface (if available) and a pipe to your favorite
pager. Additionally you may switch between hosts and databases within
one session and you don't have to type the nasty C<\g> (a trailing
C<\g>, C<\q>, and C<\p> will be ignored).

If a command starts with one of the following reserved words, it's
treated specially, otherwise it is passed on verbatim to the mSQL
daemon. Output from the daemon is piped to your pager specified by
either the PMSQL_PAGER or the PAGER environment variable. If both are
undefined, the PATH is searched for either "less" or "more" and the
first program found is taken. If no pager can be determined, the
program writes to unfiltered STDOUT.

=over 2

=item C<?>

print usage summary and current host and database

=item C<ho[st] host>

Set default host to "host"

=item C<da[tabase] database>

Set default database to "database"

=item C<re[lshow] [-h host] [database] [table]>

Describe databases or tables in the same way as done by the relshow
program. If host or database are specified, the defaults are set to
these values.

=item C<! EXPR>

Eval the EXPR in perl

=item C<q[uit]>

Leave pmsql

=back

=head2 Global Variable

The global variable C<$Q> is used for the statement handle of the
current query. You can use this variable in eval statements.

There's no global variable for the database connection, because we
connect to the database for each command separately.

=head2 Completion

pmsql comes with some basic completion definitions that are far from
being perfect. Completion means, you can use the TAB character to run
some lookup routines on the current host or database and use the
results to save a few keystrokes.

The completion mechanism is very basic, and I'm not intending to
refine it in the near future. Feel free to implement your own
refinements and let me know, if you have something better than what we
have here.

=head2 Msql::Statement::as_string

The output of select commands is formatted by an
Msql::Statement::as_string method. This works similar to the msql
monitor with a few exceptions:

=over 2

=item the width of a column

is calculated by examining the width of all entries in that column

=item control characters

are mapped into their backslashed octal
representation

=item backslashes

are doubled (C<\\ instead of \>)

=item numeric values

are adjusted right (both integer and floating point values)

=back

The differences are illustrated by the following table:

Input to msql (a real carriage return here replaced with ^M):

    CREATE TABLE demo (
      first_field CHAR(10),
      second_field INT
    ) \g

    INSERT INTO demo VALUES ('new
    line',2)\g
    INSERT INTO demo VALUES ('back\\slash',1)\g
    INSERT INTO demo VALUES ('cr^Mcrnl
    nl',3)\g

Output of msql:

     +-------------+--------------+
     | first_field | second_field |
     +-------------+--------------+
     | new
    line    | 2            |
     | back\slash  | 1            |
    crnlr
    nl  | 3            |
     +-------------+--------------+

Output of pmsql:

    +----------------+------------+
    |first_field     |second_field|
    +----------------+------------+
    |new\010line     |           2|
    |back\\slash     |           1|
    |cr\013crnl\010nl|           3|
    +----------------+------------+

=head1 BUGS

pmsql is not an msql clone. If you use it as such for bulk uploads
into the database, you will notice an enourmous disadvantage in
performance. The reason is that pmsql intentionally disconnects from
the database after every query.

=head1 SEE ALSO

You need a readline package installed to get the advantage of a
readline interface. If you don't have it, you won't be able to use the
arrow keys in a meaningful manner. Term::ReadKey and Term::ReadLine do
not come with the perl distribution but are available from CPAN (the
Comprehensive Perl Archive Network).

See Msql, Term::ReadKey, Term::ReadLine.

=cut

!NO!SUBS!

#
# End of pmsql
#

close OUT or die "Can't close $file: $!"; chmod 0755, $file or die
"Can't reset permissions for $file: $!\n";
