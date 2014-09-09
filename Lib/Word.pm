#!/usr/bin/perl
use warnings;
use strict;
use threads;
use threads::shared;
use FindBin;
use lib "$FindBin::Bin/../Lib";
use Configuration;
use Tools;
package Word;




sub new {
	my $class=shift;
	my $self = {
		sequence	=> shift,
		PromoterIDs	=> [],
		Positions	=> [],
		Intensities	=> [],
      };
      bless $self, $class;
      return $self;
}

sub getSequence {
	my $self=shift;
	return $self->{sequence};
}

sub addPromoter {
	my $self=shift;
	my $pid=shift;
	push @{$self->{PromoterIDs}}, $pid;
	return 1;
}

sub addPosition {
	my $self=shift;
	my $pos=shift;
	push @{$self->{Positions}}, $pos;
	return 1;
}

sub addIntensity {
	my $self=shift;
	my $int=shift;
	push @{$self->{Intensities}}, $int;
	return 1;
}

sub getPromoters {
	my $self=shift;
	return $self->{PromoterIDs};
}

sub getPositions {
	my $self=shift;
	return $self->{Positions};
}

sub getIntensities {
	my $self=shift;
	return $self->{Intensities};
}

1;

