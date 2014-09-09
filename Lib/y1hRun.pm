#!/usr/bin/perl

package y1hRun;

use warnings;
use strict;
use FindBin;
use lib "$FindBin::Bin/../Lib";
use Word;
use y1hData;
use Tools;

sub new {
        my $class=shift;
        my $self = {
	  	ControlData => [],
		TestData	=> [],
		output	=> [],
		ctrlIT	=> 0,
		testIT	=> 0,
        };
        bless $self, $class;
        return $self;
}

sub analyze {
}

sub getSetByID {
	my $self=shift;
	my $id=shift;
	foreach my $Set (@{$self->{TestData}}){
		my $n=$Set->getID();
		return $Set if $n eq $id;
	}
	foreach my $Set (@{$self->{ControlData}}){
		my $n=$Set->getID();
		return $Set if $n eq $id;
	}
	return undef;
}

sub getAllSources {
	my $self=shift;
	my %Sources;
	foreach my $Set (@{$self->{TestData}}){
		my @OrderedSources=@{$Set->getSourceListInOrder()};
		map {$Sources{$_}=1} @OrderedSources;
	}
	foreach my $Set (@{$self->{ControlData}}){
		my @OrderedSources=@{$Set->getSourceListInOrder()};
		map {$Sources{$_}=1} @OrderedSources;
	}
	my @Sources=keys %Sources;
	return \@Sources;
}

sub getAllDataByWell {
	my $self=shift;
	my $well=shift;
	my %D;
	$D{"C"}={};
	$D{"T"}={};
	$D{"C"}{"OD"}=[];
	$D{"C"}{"Lum"}=[];
	$D{"C"}{"IDS"}=[];
	$D{"T"}{"OD"}=[];
	$D{"T"}{"Lum"}=[];
	$D{"T"}{"IDS"}=[];
	foreach my $ctrl (@{$self->{ControlData}}){
		my %Data=%{$ctrl->getDataByWell($well)};
		my $s=scalar(@{$Data{"OD"}});
		push @{$D{"C"}{"OD"}}, @{$Data{"OD"}};
		push @{$D{"C"}{"Lum"}}, @{$Data{"Lum"}};
		for(my$i=0;$i<$s;$i++){
			push @{$D{"C"}{"IDS"}}, $ctrl->getID();
		}
	}
	foreach my $test (@{$self->{TestData}}){
		my %Data=%{$test->getDataByWell($well)};
		my $s=scalar(@{$Data{"OD"}});
		push @{$D{"T"}{"OD"}}, @{$Data{"OD"}};
		push @{$D{"T"}{"Lum"}}, @{$Data{"Lum"}};
		for(my$i=0;$i<$s;$i++){
			push @{$D{"T"}{"IDS"}}, $test->getID();
		}
	}
	return \%D;
}

sub getOrderedSourcesTest {
	my $self=shift;
	my $Set=${$self->{TestData}}[0];
	my @OrderedSources=@{$Set->getSourceListInOrder()};
	return \@OrderedSources;
}

sub getMeanActivityForTestBySource {
	my $self=shift;
	my $source=shift;
	my @means;
	foreach my $Set (@{$self->{TestData}}){
		my $meanActivity=$Set->getNormalizedActivityBySource($source);
		push @means, $meanActivity;
	}
	return hdpTools->mean(@means);
}

sub getMeanActivityForControlBySource {
	my $self=shift;
	my $source=shift;
	my @means;
	foreach my $Set (@{$self->{ControlData}}){
		my $meanActivity=$Set->getNormalizedActivityBySource($source);
		push @means, $meanActivity;
	}
	return hdpTools->mean(@means);
}

sub normalizeRunsByOD {
	my $self=shift;
	my $cutoff=shift;
	foreach my $Set (@{$self->{ControlData}}){
		my @sources=@{$Set->getSourceList()};
		foreach my $source (@sources){
			$Set->normalizeDataBySourceByOD($source,$cutoff);
		}
	}
	foreach my $Set (@{$self->{TestData}}){
		my @sources=@{$Set->getSourceList()};
		foreach my $source (@sources){
			$Set->normalizeDataBySourceByOD($source,$cutoff);
		}
	}
	return 1;
}

sub getAllNormDataBySource	{
	my $self=shift;
	my $source=shift;
	my %D;
	$D{"C"}={};
	$D{"T"}={};
	$D{"C"}{"norm"}=[];
	$D{"C"}{"IDS"}=[];
	$D{"T"}{"norm"}=[];
	$D{"T"}{"IDS"}=[];
	foreach my $ctrl (@{$self->{ControlData}}){
		next unless $ctrl->checkForSource($source);
		my @Data=@{$ctrl->getNormalizedActivityBySource($source)};
		my $s=scalar(@Data);
		push @{$D{"C"}{"norm"}}, @Data;
		for(my$i=0;$i<$s;$i++){
			push @{$D{"C"}{"IDS"}}, $ctrl->getID();
		}
	}
	foreach my $test (@{$self->{TestData}}){
		next unless $test->checkForSource($source);
		my @Data=@{$test->getNormalizedActivityBySource($source)}; ### returns array of values
		my $s=scalar(@Data);
		push @{$D{"T"}{"norm"}}, @Data;
		for(my$i=0;$i<$s;$i++){
			push @{$D{"T"}{"IDS"}}, $test->getID();
		}
	}
	return \%D;
}

sub getControlDataBySource {
	my $self=shift;
	my $source=shift;
	my %D;
	$D{"C"}={};
	$D{"C"}{"OD"}=[];
	$D{"C"}{"Lum"}=[];
	$D{"C"}{"IDS"}=[];
	foreach my $ctrl (@{$self->{ControlData}}){
		next unless $ctrl->checkForSource($source);
		my %Data=%{$ctrl->getDataBySource($source)};
		my $s=scalar(@{$Data{"OD"}});
		push @{$D{"C"}{"OD"}}, @{$Data{"OD"}};
		push @{$D{"C"}{"Lum"}}, @{$Data{"Lum"}};
		for(my$i=0;$i<$s;$i++){
			push @{$D{"C"}{"IDS"}}, $ctrl->getID();
		}
	}
	return \%D;
}

sub getAllDataBySource	{
	my $self=shift;
	my $source=shift;
	my %D;
	$D{"C"}={};
	$D{"T"}={};
	$D{"C"}{"OD"}=[];
	$D{"C"}{"Lum"}=[];
	$D{"C"}{"IDS"}=[];
	$D{"T"}{"OD"}=[];
	$D{"T"}{"Lum"}=[];
	$D{"T"}{"IDS"}=[];
	foreach my $ctrl (@{$self->{ControlData}}){
		next unless $ctrl->checkForSource($source);
		my %Data=%{$ctrl->getDataBySource($source)};
		my $s=scalar(@{$Data{"OD"}});
		push @{$D{"C"}{"OD"}}, @{$Data{"OD"}};
		push @{$D{"C"}{"Lum"}}, @{$Data{"Lum"}};
		for(my$i=0;$i<$s;$i++){
			push @{$D{"C"}{"IDS"}}, $ctrl->getID();
		}
	}
	foreach my $test (@{$self->{TestData}}){
		next unless $test->checkForSource($source);
		my %Data=%{$test->getDataBySource($source)};
		my $s=scalar(@{$Data{"OD"}});
		push @{$D{"T"}{"OD"}}, @{$Data{"OD"}};
		push @{$D{"T"}{"Lum"}}, @{$Data{"Lum"}};
		for(my$i=0;$i<$s;$i++){
			push @{$D{"T"}{"IDS"}}, $test->getID();
		}
	}
	return \%D;
}

sub getTestForSource {
	my $self=shift;
	my $source=shift;
	my %D;
	$D{"OD"}=[];
	$D{"Lum"}=[];
	$D{"ID"}=[];
	foreach my $ctrl (@{$self->{TestData}}){
		my $ID=$ctrl->getID();
		my %Data=%{$ctrl->getDataBySource($source)};
		my $s=scalar(@{$Data{"OD"}});
		push @{$D{"OD"}}, @{$Data{"OD"}};
		push @{$D{"Lum"}}, @{$Data{"Lum"}};
		for(my$i=0;$i<$s;$i++){
			push @{$D{"ID"}}, $ctrl->getID();
		}
	}
	return \%D;
}

sub getControlForSource {
	my $self=shift;
	my $source=shift;
	my %D;
	$D{"OD"}=[];
	$D{"Lum"}=[];
	$D{"ID"}=[];
	foreach my $ctrl (@{$self->{ControlData}}){
		my $ID=$ctrl->getID();
		my %Data=%{$ctrl->getDataBySource($source)};
		my $s=scalar(@{$Data{"OD"}});
		push @{$D{"OD"}}, @{$Data{"OD"}};
		push @{$D{"Lum"}}, @{$Data{"Lum"}};
		for(my$i=0;$i<$s;$i++){
			push @{$D{"ID"}}, $ctrl->getID();
		}
	}
	return \%D;
}

sub getAControlSet {
	my $self=shift;
	return $self->{ControlData}[0];
}

sub getNextCtrlSet {
	my $self=shift;
	my $i=$self->{ctrlIT};
	if(defined($self->{ControlData}[$i])){
		$self->{ctrlIT}++;
		return $self->{ControlData}[$i];
	}else{
		return undef;
	}
}

sub getNextTestSet {
	my $self=shift;
	my $i=$self->{testIT};
	if(defined($self->{TestData}[$i])){
		$self->{testIT}++;
		return $self->{TestData}[$i];
	}else{
		return undef;
	}
	die "Got here somehow.\n";
}

sub addTestSet {
	my $self	=shift;
	my $datafile=shift;
	my $layout	=shift;
	my $id	=shift;
	warn "Adding Test Set $datafile with $layout\n\n";
	my $set=y1hData->new($layout,$datafile,$id);
	push @{$self->{TestData}}, $set;
	return 1;
}

sub getStatus {
	my $self=shift;
	warn scalar(@{$self->{ControlData}})." datasets as controls\n";
	warn scalar(@{$self->{TestData}})." datasets as tests\n";
	return 1;
}

sub addControlSet {
	my $self	=shift;
	my $datafile=shift;
	my $layout	=shift;
	my $id	=shift;
	warn "Adding Control Set $datafile with $layout\n\n";
	my $set=y1hData->new($layout,$datafile,$id);
	push @{$self->{ControlData}}, $set;
	return 1;
}

1;
