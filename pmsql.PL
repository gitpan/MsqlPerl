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

print OUT <<"!GROK!THIS!";
$Config{'startperl'}
!GROK!THIS!
print OUT <<'!NO!SUBS!';

require 5.002;
#use strict;
use Msql;
use Term::ReadLine;
use Carp ();

$SIG{'__WARN__'} = sub { warn Carp::longmess(@_); };

my(%bottom,@typelabel);
my $opt_h = "";
sub Usage () {"Usage: $0 [-h host] database";}

if (@ARGV && $ARGV[0] eq "-h") {
    shift;
    $opt_h = shift or die Usage;
}

my @path = split ":", $ENV{PATH}; # sorry, UNIX only
my $Less = $ENV{PMSQL_PAGER} || $ENV{PAGER} || find_exe("less",[@path]) || 
                find_exe("more",[@path]) || "";

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

format dbs_top =
  +-----------------+
  |    Databases    |
  +-----------------+
.
format dbs =
  | @<<<<<<<<<<<<<< |
    $::elem
.
$bottom{dbs} = "  +-----------------+";

format tbl_top =
  +---------------------+
  |       Table         |
  +---------------------+
.
format tbl =
  | @<<<<<<<<<<<<<<<<<  |
    $::elem
.
$bottom{tbl} = "  +---------------------+";

format fld_top =
 +-----------------+--------+--------+----------+-----+
 |     Field       |  Type  | Length | Not Null | Key |
 +-----------------+--------+--------+----------+-----+
.
format fld =
 | @<<<<<<<<<<<<<  | @||||| | @>>>>> |     @|   |  @| |
   @::row
.
$bottom{fld} = " +-----------------+--------+--------+----------+-----+";

@typelabel[Msql::CHAR_TYPE(),Msql::INT_TYPE(),Msql::REAL_TYPE()] = qw(char int real);
$= = 1e9; # must be integer!

package Msql::Statement;
use vars qw(@row);

sub as_string {
    my($sth) = @_;
    my($plusline,$titline,$sprintf,$result,$s) = ('+','|','|');
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
    $sprintf .= "\n";
    print $@ if $@;
    $result = "$plusline\n$titline\n$plusline\n";
    $sth->DataSeek(0);
    while (@row = map {defined $_ ? $_ : "NULL"} $sth->FetchRow) {
	$result .= sprintf $sprintf, @row;
    }
    $result .= "$plusline\n";
    $s = $sth->numrows == 1 ? "" : "s";
    $result .= $sth->numrows . " row$s processed\n\n";
    return $result;
}

package main;
my $term = new Term::ReadLine 'MsqlPerl Monitor';
my $prompt = "Enter Query> ";
my $database = $ARGV[0];
$^W = 1;
my $version = substr(q$Revision: 1.15 $, 10);
my $rl_avail = defined &Term::ReadLine::Perl::readline ? "enabled" : "available (get Term::ReadKey and Term::ReadLine::Perl)";
print <<END;

pmsql -- interactive mSQL monitor version $version
Readline support $rl_avail

END
while ( defined ($_ = $term->readline($prompt)) ) {
    if (/^\!/) {
	$term->addhistory($_) if /\S/;
	s/^\!//;
	eval($_);
	warn $@ if $@;
	print "\n";
	next;
    } elsif (/^\?/) {
	print qq{
ho[st] <host>                            Set default host (current is "$opt_h")
da[tabase] <database>                    Set default database (current is "$database")
re[lshow] [-h host] [database] [table]   describe databases or tables and
                                                  set default host and database
! <anything>                             eval string in perl
?                                        print this message
q[uit]                                   leave pmsql
<anything else>                          query the default database on default host

};
	next;
    }

    my($command,@arg) = /^\s*(\w+)\s*(\w*)\s*(\w*)/;
    next unless defined $command;

    if ($command =~ /^ho(s(t)?)?$/i) {
	$opt_h = $arg[0];
	print qq{Host set to "$opt_h"\n};
    } elsif ($command =~ /^da(t(a(b(a(s(e)?)?)?)?)?)?$/i) {
	$database = $arg[0] if $arg[0] gt "";
	print qq{Database set to "$database"\n};
    } elsif ($command =~ /^re(l(s(h(o(w)?)?)?)?)?$/i) {
	relshow(@arg);
    } elsif ($command =~ /^q(u(i(t)?)?)?$/i) {
	print "Goodbye\n";
	last;
    } else {
	s/\\[qgp]$//;
	my $Db = Msql->Connect($opt_h,$database) or next;
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

sub relshow {
    $- = 0;
    if (@_ && $_[0] eq "-h") {
	shift @_;
	$opt_h = shift @_ or die Usage;
    }

    if (@_ > 2){
	print "Usage: relshow [-h host] [database] [table]\n";
	return;
    }

    print "Host = $opt_h\n" if $opt_h;
    my $Dbh = Msql->Connect($opt_h) or return;

    my($table,$bottok,$sorry,$i);

    if ($_[0]) {
	$database = shift @_;
	unless ( $Dbh->SelectDB($database) ) {
	    print "Couldn't connect to $database\n";
	    return;
	}
	print "\nDatabase = $database\n";
	if ($table = shift @_) {
	    grep /^\Q$table\E$/, $Dbh->ListTables or print qq{Table "$table" not found\n} and return;
	    my $sth = $Dbh->ListFields($table) or return;
	    print "Table = $table\n";
	    ($~,$^) = ("fld","fld_top");
	    my $max = $sth->numfields;
	    for ($i=0;$i<$max;$i++){
		@::row = (
			$sth->name->[$i], 
			$typelabel[$sth->type->[$i]] || "unknown",
			$sth->length->[$i],
			$sth->is_not_null->[$i] ? "Y" : "N",
			$sth->is_pri_key->[$i] ? "Y" : "N"
		       );
		write;
		$bottok||=1;
	    }
	} else {
	    ($~,$^) = ("tbl","tbl_top");
	    $sorry = "No tables in database";
	    for $::elem ($Dbh->ListTables) {
		write;
		$bottok||=1;
	    }
	}
    } else {
	($~,$^) = ("dbs","dbs_top");
	$sorry = "No databases found";
	for $::elem ($Dbh->ListDBs) {
	    write;
	    $bottok||=1;
	}
    }
    if ($bottok){
	print "$bottom{$~}\n";
    } else {
	print "$sorry\n";
    }
}


__END__

=head1 NAME

pmsql - interactive shell with readline for msql

=head1 SYNOPSIS

C<pmsql [-h host] [database]>

=head1 DESCRIPTION

pmsql lets you talk to a running msql daemon sending either SQL
queries or relshow commands. The output is formatted much in the same
way as by the msql monitor and the relshow program, which are both
coming with msql. The additional capability is a connection to a
readline interface (if available) and a pipe to your favorite
pager. Additionally you may switch between hosts and databases within
one session and you don't have to type the nasty C<\g> (a trailing
C<\g>, C<\q>, and C<\p> will be ignored).

If a command starts with one of the following reserved words, it is
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

=head1 GLOBAL VARIABLE

The global variable C<$Q> is used for the statement handle of the
current query. You can use this variable in eval statements.

There's no global variable for the database connection, because we
connect for each command separately to the database.

=head1 SEE ALSO

You need a readline package installed to get the advantage of a
readline interface. If you don't have it, you won't be able to use the
arrow keys in a meaningful manner. Term::ReadKey and Term::ReadLine do
not come with the perl distribution but are available from CPAN (the
Comprehensive Perl Archive Network).

See Msql, Term::ReadKey, Term::ReadLine.

=cut

!NO!SUBS!

close OUT or die "Can't close $file: $!";
chmod 0755, $file or die "Can't reset permissions for $file: $!\n";
