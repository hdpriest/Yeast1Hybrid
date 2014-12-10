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
		DataBySets  => {},
		Plates	=> {},
		output	=> [],
		iter		=> undef
        };
        bless $self, $class;
        return $self;
}

sub initializeSet {
	my $self=shift;
	my $set=shift;
	$self->{DataBySets}{$set}=[];
	return 1;
}

sub addPlate {
	my $self=shift;
	my $Plate 	=shift;
	my $set	=shift;
	my $id = $Plate->getID();
	die "Can't add $id to $set - not initilized.\n" unless defined $self->{DataBySets}{$set};
	$self->{Plates}{$id}=$Plate;
	push @{$self->{DataBySets}{$set}}, $Plate;
	return 1;
}
sub getPlatesBySet {
	my $self	=shift;
	my $set 	=shift;
	if(defined($self->{DataBySets}{$set})){
		return $self->{DataBySets}{$set};
	}else{
		return undef;
	}
}
sub analyze {
}

sub _initIterator {
	my $self=shift;
	my @IDs = keys %{$self->{Plates}};
	$self->{IDs} = \@IDs;
	$self->{iter}= 0;
	return $self;
}

sub getNextPlate {
	my $self=shift;
	$self = _initIterator($self) unless defined $self->{iter};
	return undef if $self->{iter} >= scalar(keys %{$self->{Plates}});
	my $id = $self->{IDs}[$self->{iter}];
	my $Plate = $self->{Plates}{$id};
	$self->{iter}++;
	return $Plate;
}

sub getPlateByID {
	my $self=shift;
	my $id=shift;
	if(defined($self->{Plates}{$id})){
		return $self->{Plates}{$id};
	}else{
	}
	return undef;
}

sub getAllSources {
	my $self=shift;
	my %Sources;
	foreach my $id (keys %{$self->{Plates}}){
		my $Plate = $self->{Plates}{$id};
		my @OrderedSources=@{$Plate->getSourceListInOrder()};
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
	foreach my $set (keys %{$self->{DataBySets}}){
		foreach my $Plate (@{$self->{DataBySets}{$set}}){
			my %Data=%{$Plate->getDataByWell($well)};
			my $s=scalar(@{$Data{"OD"}});
			push @{$D{"C"}{"OD"}}, @{$Data{"OD"}};
			push @{$D{"C"}{"Lum"}}, @{$Data{"Lum"}};
			for(my$i=0;$i<$s;$i++){
				push @{$D{"C"}{"IDS"}}, $Plate->getID();
			}
		}
	}
	return \%D;
}

sub normalizeRunsByOD {
	my $self=shift;
	my $cutoff=shift;
	die "Method not converted\n";
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
	die "method not converted\n";
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

sub getAllDataBySource	{
	my $self=shift;
	my $source=shift;
	my %D;
	die "Method not converted\n";
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

sub getStatus {
	my $self=shift;
	warn scalar(@{$self->{ControlData}})." datasets as controls\n";
	warn scalar(@{$self->{TestData}})." datasets as tests\n";
	return 1;
}


sub parseExperiment {
	my $self=shift;
	my $config=shift;
	my @codes = @{$_[0]};
	my %E;
	my $iDir = $config->get("PATHS","DataDir");
	foreach my $line (@codes){
		next if $line =~ m/^\#/;
		my ($code,$info)=split(/\s+/,$line);
		my $nCode = sprintf("%05d",$code);
		my %Plate;
		if($info=~m/diploid$/){
			my ($date,$layout,$set,$TF,$rep,$indiv,$celltype)=split(/\_/,$info);
			$layout=~s/layout//;
			$rep=~s/rep//;
			$Plate{"D"}=$date;
			$Plate{"L"}=$layout;
			$Plate{"S"}=$set;
			$Plate{"T"}=$TF;
			$Plate{"R"}=$rep;

			$E{dip}{$nCode}=\%Plate;
			$self->initializeSet($set);
		}elsif($info=~m/haploid$/){
			my ($date,$layout,$set,$TF,$rep,$indiv,$celltype)=split(/\_/,$info);
			$layout=~s/layout//;
			$Plate{"D"}=$date;
			$Plate{"L"}=$layout;
			$Plate{"S"}=$set;
			$Plate{"T"}=$TF;
			$Plate{"R"}=$rep;
			$E{hap}{$nCode}=\%Plate;
			$self->initializeSet($set);
		}else{
			warn "Malformed barcode line!\n$line\n";
		}
	}
	opendir(DIR,$iDir) || die "Cannot open directory: $iDir!\n$!\nexiting...\n";
	my @files=grep {m/txt$/} readdir(DIR);
	closedir DIR;
	foreach my $file (@files) {
		my @F=split(/\_/,$file);
		my $path=$iDir."/".$file;
		if(defined($E{dip}{$F[2]})){
			my %P = %{$E{dip}{$F[2]}};
			warn "$file is a diploid test file of set $P{S}\n";
			my $L = $iDir."/".$config->get("LAYOUTS",$P{L});
			my $ID = $P{S}."-".$P{T}."-".$P{R}."-".$P{L}."-".$F[2];
			my $D = $path;
		#	warn $F[2]."\n".$L."\n".$ID."\n".$D."\n";
			my $Plate = y1hPlate->new($L,$D,$ID);
			$self->addPlate($Plate,$P{S});
		}elsif(defined($E{hap}{$F[2]})){
			warn "$file is a haploid QC file\n";
			my %P = %{$E{hap}{$F[2]}};
			next if $P{S} eq "TF";
			my $L = $iDir."/".$config->get("LAYOUTS",$P{L});
			my $ID = $P{S}."-".$P{T}."-".$P{R}."-".$P{L}."-".$F[2];
			my $D = $path;
			#warn $F[2]."\n".$L."\n".$ID."\n".$D."\n";
			my $Plate = y1hPlate->new($L,$D,$ID);
			$self->addPlate($Plate,$P{S});
		}else{
			warn "Not Handled: $file\n";
		}
	}
	return 1;
}

1;
