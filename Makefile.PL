use ExtUtils::MakeMaker;
require 5.001;

if ($ExtUtils::MakeMaker::Version >= 4.15) {
    # This is important only for the developer:
    $X{'macro'} = {CONFIGDEP => '$(PERL_ARCHLIB)/Config.pm $(PERL_INC)/config.h lib/Msql.pm'};
}

if ($ExtUtils::MakeMaker::Version < 4.17) {
    &initialize();
    $X{LIBS}     = "-L$libdir -lmsql -lmisc";
    $X{INC}      = "-I$headerdir";
    $X{H}        = \@headerfiles;
    $X{VERSION}  = $VERSION;
} else {
    $X{CONFIGURE} = \&initialize;
}


WriteMakefile(%X);



sub initialize {
    %X=(
	NAME       => "Msql",
	"DISTNAME" => "MsqlPerl",
	"clean"    => { FILES => 'Msql.pm.html bench/*~' },
	"dist"     => { SUFFIX   => "gz", DIST_DEFAULT => 'all uutardist',
			    COMPRESS => "gzip -9f",
			},
       );
    $Minervadir="/usr/local/Minerva";
    
    if (-f "$Minervadir/include/msql.h") {
	print "Assuming \"$Minervadir\" is your Minerva directory\n";
    } else {
	$Minervadir=prompt("
Where is your msql installed? Please name the directory that contains
the subdirs lib/ and include/.",$Minervadir);
    }
    
    $headerdir="$Minervadir/include";
    die "No msql.h file found\n" unless -f "$headerdir/msql.h";
    $libdir="$Minervadir/lib";
    
    open MSQL, "lib/Msql.pm" or die "open: $!";
    while (!$VERSION){
	$_=<MSQL>;
	next unless /VERSION/;
	eval;
    }
    close MSQL;
    
    @headerfiles = ("$headerdir/msql.h");
    $X{LIBS}     = "-L$libdir -lmsql -lmisc";
    $X{INC}      = "-I$headerdir";
    $X{H}        = \@headerfiles;
    $X{VERSION}  = $VERSION;
    \%X;
}


