BEGIN {require 5.002;}
use ExtUtils::MakeMaker;
$Verbose++ if $ENV{USER} eq "k";

WriteMakefile(
	      NAME       => "Msql",
	      "DISTNAME" => "MsqlPerl",
	      "dist"     => { SUFFIX   => ".gz", DIST_DEFAULT => 'all tardist',
			      COMPRESS => "gzip -9f" },
	      VERSION_FROM => "lib/Msql.pm",
	      EXE_FILES => [qw(pmsql)],
	      CONFIGURE  => \&initialize,
	      @VERSION,
);

sub MY::postamble {
    return qq{
pure_all :: FAQ.html

FAQ.html : FAQ
	pod2html FAQ
};
}


sub initialize {
    my %X=();
    my @msqldir = qw(/usr/local/Hughes /usr/local/Minerva /usr/local);
    my($msqldir,$gooddir);

    for $msqldir (@msqldir) {
	if (-f "$msqldir/include/msql.h") {
	    $gooddir = $msqldir;
	    last;
	}
    }
    $gooddir ||= $msqldir[0];
    $gooddir=prompt("
Where is your msql installed? Please name the directory that contains
the subdirs lib/ and include/.",$gooddir) || $gooddir; # || for 5.002
    
    my $headerdir="$gooddir/include";
    die "No msql.h file found\n" unless -f "$headerdir/msql.h";
    my $libdir="$gooddir/lib";
    
    @headerfiles = ("$headerdir/msql.h");
    $X{LIBS}     = "-L$libdir -lmsql";
    $X{INC}      = "-I$headerdir";
    $X{H}        = \@headerfiles;
    \%X;
}


