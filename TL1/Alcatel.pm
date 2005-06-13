package Net::TL1::Alcatel;
@ISA = qw(Net::TL1);

use Net::TL1;

use strict;
use warnings;

sub rtrvxdsl {
	my $this = shift;

	my ($ref) = @_;
	$$ref{ctag} = defined $$ref{ctag} ? $$ref{ctag} : $this->get_newctag();

	my $string = $this->get_linecommand
		('RTRV-XDSL', 'XDSL', $$ref{ctag}, $ref);

	return undef if !defined $string;

	my $result = $this->Execute ($string);

	return undef if $this->is_error($$ref{ctag});

	$this->ParseCompoundOutputLines ($$ref{ctag});
	return $$ref{ctag};
}

sub reptopstatxlnecom {
	my $this = shift;

	my ($ref) = @_;

	$$ref{ctag} = defined $$ref{ctag} ? $$ref{ctag} : $this->get_newctag();

	my $string = $this->get_linecommand
		('REPT-OPSTAT-XLNECOM', 'XDSL', $$ref{ctag}, $ref);

	return undef if !defined $string;

	my $result = $this->Execute ($string);
	return undef if  $this->is_error($$ref{ctag});

	$this->ParseSimpleOutputLines ($$ref{ctag});
	return $$ref{ctag};
}

sub reptopstatxbearer {
	my $this = shift;

	my ($ref) = @_;

	$$ref{ctag} = defined $$ref{ctag} ? $$ref{ctag} : $this->get_newctag();

	my $string = $this->get_linecommand
		('REPT-OPSTAT-XBEARER', 'XDSL', $$ref{ctag}, $ref);

	return undef if !defined $string;

	my $result = $this->Execute ($string);
	return undef if  $this->is_error($$ref{ctag});

	$this->ParseSimpleOutputLines ($$ref{ctag});

	return $$ref{ctag};
}

sub reptopstatxline {
	my $this = shift;

	my ($ref) = @_;

	$$ref{ctag} = defined $$ref{ctag} ? $$ref{ctag} : $this->get_newctag();

	my $string = $this->get_linecommand
		('REPT-OPSTAT-XLNE', 'XDSL', $$ref{ctag}, $ref);

	return undef if !defined $string;

	my $result = $this->Execute ($string);
	return undef if  $this->is_error($$ref{ctag});

	$this->ParseSimpleOutputLines ($$ref{ctag});

	return $$ref{ctag};
}

sub get_linecommand {
	my $this = shift;

	my ($cmd, $aid, $ctag, $ref) = @_;

	return undef if !defined $$ref{Target};
	return undef if !defined $$ref{Rack} || !defined $$ref{Shelf}
		|| !defined $$ref{Slot};
	return undef if !defined $$ref{Circuit} &&
		(!defined $$ref{FirstCircuit} || !defined $$ref{LastCircuit});

	my $string =
		"$cmd:$$ref{Target}:$aid-$$ref{Rack}-$$ref{Shelf}-$$ref{Slot}-";
	if (defined $$ref{Circuit}) {
		$string .= $$ref{Circuit};
	} else {
		$string .= "$$ref{FirstCircuit}&&-$$ref{LastCircuit}";
	}
	$string .= ":$$ref{ctag}:;";
	$this->{Debug} && print STDERR "$string\n";
	return $string;
}

1;
__END__

=head1 NAME

Net::TL1::Alcatel - Perl extension for managing Alcatel network devices using TL1

=head1 SYNOPSIS

  use Net::TL1::Alcatel;

  $obj = new Net::TL1::Alcatel ({Host => $host, Debug => [ 0 | 1 ],
                                Port => $port});

  $obj->Login ({Target => $target, User => $username,
                Password => $password, ctag => $ctag});
  $obj->Logout ({Target => $target});
  $obj->Execute($cmd);

  $ctag = $obj->rtrvxdsl({ctag => $ctag});
  $ctag = $obj->reptopstatxlnecom({ctag => $ctag});
  $ctag = $obj->reptopstatxbearer({ctag => $ctag});
  $ctag = $obj->reptopstatxline({ctag => $ctag});

  $obj->is_error($ctag);
  $obj->ParseRaw;
  $obj->ParseHeader;
  $obj->ParseBody;
  $obj->ParseSimpleOutputLines($ctag);
  $obj->ParseCompoundOutputLines($ctag);

  $obj->get_hashref;
  $obj->get_hashref($ctag);

  $obj->dumpraw;
  $obj->dumphash;
  $obj->dumphash($ctag);

  $obj->close;

=head1 DESCRIPTION

Transaction Language 1 is a configuration interface to network
devices used in public networks. Through its very structured but
human-readable interface it is very suitable to provide the glue for
netwerk device <-> OSS integration.

The Net::TL1 module provides an interface to the sometimes arcane
TL1 commands and parses the output of these commands for easy
processing in scripts.

At this time the support for the different commands and features is
quite limited. Not all the required commands are supported and neither
is alarm processing.

=head2 REQUIRES

  Net::Telnet

=head2 EXPORT

  (none)

=head1 AUTHOR

Steven Hessing, E<lt>stevenh@xsmail.comE<gt>

=head1 SEE ALSO

L<http://www.tl1.com/>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2005, Steven Hessing. All rights reserved. This
program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

