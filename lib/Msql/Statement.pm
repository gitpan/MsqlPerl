package Msql::Statement;

use vars qw($VERSION);

$VERSION = substr q$Revision: 1.12 $, 10;
# $Id: Statement.pm,v 1.12 1996/06/01 15:25:47 k Exp $

sub numrows    { shift->fetchinternal( 'NUMROWS'   ) }
sub numfields  { shift->fetchinternal( 'NUMFIELDS' ) }
sub table      { return wantarray ? @{shift->fetchinternal('TABLE'    )}: shift->fetchinternal('TABLE'    )}
sub name       { return wantarray ? @{shift->fetchinternal('NAME'     )}: shift->fetchinternal('NAME'     )}
sub type       { return wantarray ? @{shift->fetchinternal('TYPE'     )}: shift->fetchinternal('TYPE'     )}
sub isnotnull  { return wantarray ? @{shift->fetchinternal('ISNOTNULL')}: shift->fetchinternal('ISNOTNULL')}
sub isprikey   { return wantarray ? @{shift->fetchinternal('ISPRIKEY' )}: shift->fetchinternal('ISPRIKEY' )}
sub length     { return wantarray ? @{shift->fetchinternal('LENGTH'   )}: shift->fetchinternal('LENGTH'   )}


sub AUTOLOAD {
    my $meth = $AUTOLOAD;
    $meth =~ s/^Msql::Statement:://;
    $meth =~ s/_//g;
    $meth = lc($meth);

    # Allow them to say fetch_row or FetchRow
    if (defined &$meth) {
	*$AUTOLOAD = \&{$meth};
	return &$AUTOLOAD(@_);
    }
    Carp::croak "$AUTOLOAD not defined and not autoloadable";
}

1;
__END__
