package Net::TL1;

# Copyright (c) 2005, Steven Hessing. All rights reserved. This
# program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.

use Net::Telnet;

use 5.006;
use strict;
use warnings;

our $VERSION = '0.01';

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;

	my $ref = shift;
	$self->{Debug} = defined $$ref{Debug} ? $$ref{Debug} : 0;
	$self->{Port} = defined $$ref{Port} ? $$ref{Port} : 14000;
	$self->{Telnet} = new Net::Telnet
		(Timeout => 60, Port => $self->{Port}, Prompt => '/;/');
	if (defined $$ref{Host}) {
		$self->{Host} = $$ref{Host};
		($self->{Telnet})->open($self->{Host});
	}

	#
	# The values below only hold the data of the last executed command
	#
	$self->{Target} = '';
	$self->{Date} = '';
	$self->{Time} = '';
	@{$self->{Result}{Raw}} = ();

	#
	# These variables hold data of all executed commands as long
	# as they had unique ctags
	#
	%{$self->{Commands}} = ();
	# $self->{Commands}{$ctag}{Result}
	# $self->{Commands}{$ctag}{Error}
	# @{$self->{Commands}{$ctag}{Output}}

	@{$self->{ctags}} = ();

    return $self;
}

sub close {
	my $this = shift;

	$this->{Telnet}->close;
	return $this->{Telnet} = undef;
}

sub get_hashref {
	my $this = shift;

	my ($ctag) = @_;
	$ctag = $this->{ctags}[@{$this->{ctags}} - 1]
		if !defined $ctag;

	return $this->{Commands}{$ctag}{Hash};
}

sub Execute {
	my $this = shift;

	return undef if !defined $this->{Telnet};

	my $cmd = shift;
	@{$this->{Result}{Raw}} = $this->{Telnet}->cmd ($cmd);
	return $this->ParseRaw;
}

sub ParseSimpleOutputLines {
	my $this = shift;

	my ($ctag) = @_;

	foreach my $line (@{$this->{Commands}{$ctag}{Output}}) {
		if ($line =~ /^\s*"(\w+)-(\d+)-(\d+)-(\d+)-(\d+):(\w+),(.*)"\s*$/) {
			my ($aid, $rack, $shelf, $slot, $port, $param, $value) = 
				($1, $2, $3, $4, $5, $6, $7);
			if ($value =~ /^\s*\\"(.*)\\"\s*$/) {
				$value = $1;
			}

			$this->{Commands}{$ctag}{Hash}{$aid}{$rack}{$shelf}{$slot}{$port}{$param} = $value;
		} else {
			$this->{Debug} > 4 && print STDERR "Couldn't parse: $line\n";
		}
	}
	return scalar(@{$this->{Commands}{$ctag}{Output}});
}

sub ParseCompoundOutputLines {
	my $this = shift;

	my ($ctag) = @_;

	foreach my $line (@{$this->{Commands}{$ctag}{Output}}) {
		if ($line =~ /^\s*"(\w+)-(\d+)-(\d+)-(\d+)-(\d+)::(.+):(\S+),"\s*$/) {
			my ($aid, $rack, $shelf, $slot, $port) = ($1, $2, $3, $4, $5);
			my @data = split /,/, $6;
			while (my $combo = shift @data) {
				my ($param, $value) = split /=/, $combo;
				if ($value =~ /^\s*\\"(.*)\\"\s*$/) {
					$value = $1;
				}
				$this->{Commands}{$ctag}{Hash}{$aid}{$rack}{$shelf}{$slot}{$port}{$param} = $value;
			}
		} else {
			$this->{Debug} > 4 && print STDERR "Couldn't parse: $line\n";
		}
	}
	return scalar(@{$this->{Commands}{$ctag}{Output}});
}

sub ParseRaw {
	my $this = shift;

	my $lines = @{$this->{Result}{Raw}};
	my $index = 0;
	my ($skip, $ctag);
	my $ctag_added = 0;
	do {
		($skip, $ctag) = $this->ParseHeader($index);
		if (! $ctag_added) {
			push @{$this->{ctags}}, $ctag;
			$ctag_added = 1;
		}

		$this->{Debug} > 2 && print STDERR "Skip $skip lines for header\n";
		# If no header present then skip will be 0
		if ($skip) {
			$index += $skip;
			$skip = $this->ParseBody($index, $ctag);
			$this->{Debug} > 2 &&  print STDERR "Skip $skip lines for body\n";
			$index += $skip;
		}
	} until ($index >= ($lines - 1) || $skip == 0);
	return $this->{Commands}{$ctag}{Result};
}

sub ParseHeader {
	my $this = shift;

	my ($start) = @_;

	my $lines = @{$this->{Result}{Raw}} - 1;
	my $read;
	foreach my $index ($start .. $lines) {
		$this->{Debug} > 3 &&
			print STDERR "READ($index): $this->{Result}{Raw}[$index]";
		if ($this->{Result}{Raw}[$index] =~
				/^\s*(\S+)\s+(\d{2}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})/) {
			$this->{Target} = $1;
			$this->{Date} = $2;
			$this->{Time} = $3;
			$read = $index;
			$this->{Debug} > 3 && print STDERR "SET ($index) Target to $1\n";
			last;
		}
	}

	my $line = $this->{Result}{Raw}[++$read];
	$this->{Debug} > 3 && print STDERR "READ ($read): $line";
	my $ctag;
	my $rc;
	if ($line =~ /^\s*M\s+(\d+)\s+(\S+)\s*$/) {
		$ctag = $1;
		$rc = $this->{Commands}{$ctag}{Result} = $2;
	}
	$line = $this->{Result}{Raw}[++$read];
	$this->{Debug} > 3 && print STDERR "READ ($read): $line";
	if ($line =~ /^\s*\/\*\s*(\S+)\s*\*\/\s*$/) {
		$this->{Commands}{$ctag}{Command} = $1;
	}
	if (defined $rc && $rc eq 'DENY') {
		$line = $this->{Result}{Raw}[++$read];
		$this->{Debug} > 3 && print STDERR "READ: $line";
		$this->{Commands}{$ctag}{Error} = $line;
		return 0;
	}
	return ($read + 1 - $start, $ctag);
}

sub ParseBody {
	my $this = shift;

	my ($start, $ctag) = @_;

	my $lines = @{$this->{Result}{Raw}};
	my $read = $lines - $start;
	$this->{Debug} > 0 && print STDERR "BODY containts $read lines\n";
	my $line = "";
	foreach my $index ($start .. $lines - 1) {
		$this->{Debug} > 1 &&
			print STDERR "BODY ($index): $this->{Result}{Raw}[$index]";
		$read = $index;
		if ($this->{Result}{Raw}[$index] !~ /^\s*$/) {
			last if $this->{Result}{Raw}[$index] =~
				/\/\* More Output Follows \*\//;
			if ($this->{Result}{Raw}[$index] !~ /^\s*\/\*.*\*\/\s*$/) {
				if ($this->{Result}{Raw}[$index] =~ /^\s*(\S+.*\S+)\s*$/) {
					$this->{Result}{Raw}[$index] = $1;
				}
				$line .= $this->{Result}{Raw}[$index];
				if ($this->{Result}{Raw}[$index] =~ /"\s*$/) {
					push @{$this->{Commands}{$ctag}{Output}}, $line;
					$line = "";
				}
			}
		}
	}
	return $read + 1 - $start;
}

sub dumpraw {
	my $this = shift;

	print STDERR "$this->{Target} - $this->{Time} - $this->{Date}\n";
	foreach my $ctag (@{$this->{ctags}}) {
		print STDERR "CTAG: $ctag -> $this->{Commands}{$ctag}{Command} -> $this->{Commands}{$ctag}{Result}\n";
		if ($this->is_error($ctag)) {
			print STDERR "Error: $this->{Commands}{$ctag}{Error}\n";
		} else {
			foreach my $line (@{$this->{Commands}{$ctag}{Output}}) {
				print STDERR "-> $line\n";
			}
		}
	}
}

sub dumphash {
	my $this = shift;

	my ($ctag) = @_;
	my @tags;
	if (defined $ctag) {
		@tags = $ctag;
	} else {
		@tags = @{$this->{ctags}};
	}
	foreach $ctag (@tags) {
		print STDERR "CTAG: $ctag -> $this->{Commands}{$ctag}{Command} -> $this->{Commands}{$ctag}{Result}\n";
		if ($this->is_error($ctag)) {
			print STDERR "Error: $this->{Commands}{$ctag}{Error}\n";
		} else {
			foreach my $class (keys %{$this->{Commands}{$ctag}{Hash}}) {
				my $class_ref = $this->{Commands}{$ctag}{Hash}{$class};
				foreach my $rack (sort {$a <=> $b} keys %{$class_ref}) {
					foreach my $shelf (sort {$a <=> $b} keys %{$$class_ref{$rack}}) {
						foreach my $slot (sort {$a <=> $b} keys %{$$class_ref{$rack}{$shelf}}) {
							foreach my $circuit (sort {$a <=> $b} keys %{$$class_ref{$rack}{$shelf}{$slot}}) {
								foreach my $param (sort keys %{$$class_ref{$rack}{$shelf}{$slot}{$circuit}}) {
									print STDERR "$class-$rack-$shelf-$slot-$circuit->$param -> $$class_ref{$rack}{$shelf}{$slot}{$circuit}{$param}\n";
								}
							}
						}
					}
				}
			}
		}
	}
}
	
	
sub get_newctag {
	my $this = shift;

	return int(rand(1000000));
}

sub is_error {
	my $this = shift;

	my ($ctag) = @_;

	return 1 if ($this->{Commands}{$ctag}{Result} ne 'COMPLD');
	return 0;
}

1;
__END__

=head1 NAME

Net::TL1 - Perl extension for managing network devices using TL1

=head1 SYNOPSIS

  use Net::TL1;

  $obj = new Net::Telnet ({Host => $host, Debug => [ 0 | 1 ], Port => $port});

  $obj->Execute($cmd);
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

