package Msql::Statement;

sub AUTOLOAD {
    $AUTOLOAD =~ s/.*://;
    # add some code that checks the validity of the function name
    Carp::croak("Invalid method call '$AUTOLOAD' in package Msql::Statement")
	unless $AUTOLOAD eq "numrows" || 
	       $AUTOLOAD eq "numfields" ||
	       $AUTOLOAD eq "table" ||
	       $AUTOLOAD eq "name" ||
	       $AUTOLOAD eq "type" ||
	       $AUTOLOAD eq "is_not_null" ||
	       $AUTOLOAD eq "is_pri_key" ||
	       $AUTOLOAD eq "length" ||
	       $AUTOLOAD eq "db";
    my $auto = uc $AUTOLOAD;
    eval "sub $AUTOLOAD {return shift->fetchinternal($auto);}";
    goto &$AUTOLOAD;
}

1;
__END__
