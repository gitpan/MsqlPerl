use ExtUtils::MakeMaker;
require 5.002;
$Verbose++ if $ENV{USER} eq "k";


WriteMakefile(
	NAME       => "Msql",
	"DISTNAME" => "MsqlPerl",
	"dist"     => { SUFFIX   => ".gz", DIST_DEFAULT => 'all tardist',
			    COMPRESS => "gzip -9f" },
        VERSION_FROM => "lib/Msql.pm",
	EXE_FILES => [qw(pmsql)],
	CONFIGURE  => \&initialize,
);



sub initialize {
    my %X=();
    my $minervadir="/usr/local/Minerva";

    if (-f "$minervadir/include/msql.h") {
	print "Assuming \"$minervadir\" is your Minerva directory\n";
    } else {
	$minervadir=prompt("
Where is your msql installed? Please name the directory that contains
the subdirs lib/ and include/.",$minervadir);
    }
    
    my $headerdir="$minervadir/include";
    die "No msql.h file found\n" unless -f "$headerdir/msql.h";
    my $libdir="$minervadir/lib";
    
    @headerfiles = ("$headerdir/msql.h");
    $X{LIBS}     = "-L$libdir -lmsql";
    $X{INC}      = "-I$headerdir";
    $X{H}        = \@headerfiles;
    \%X;
}


