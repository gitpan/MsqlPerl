package Msql::Statement;

use vars qw($Optimize_Table $VERSION);

$VERSION = substr q$Revision: 1.13 $, 10;
# $Id: Statement.pm,v 1.13 1996/07/11 21:05:30 k Exp $

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

sub unctrl {
    my($x) = @_;
    $x =~ s/\\/\\\\/g;
    $x =~ s/([\001-\037\177])/sprintf("\\%03o",unpack("C",$1))/eg;
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
    $sth->dataseek(0);
    my(@row);
    while (@row = map {defined $_ ? unctrl($_) : "NULL"} $sth->fetchrow) {
	$result .= sprintf $sprintf, @row;
    }
    $result .= "$plusline\n";
    $s = $sth->numrows == 1 ? "" : "s";
    $result .= $sth->numrows . " row$s processed\n\n";
    return $result;
}


1;
__END__
