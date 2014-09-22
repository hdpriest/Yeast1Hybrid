#!/usr/bin/perl

package y1hPlate;

use warnings;
use strict;
use FindBin;
use lib "$FindBin::Bin/../Lib";
use Tools;

sub new {
        my $class=shift;
        my $self = {
	  	LayoutFile	=> shift,
		DataFile	=> shift,
		ID		=> shift,
		OrdSources	=> [],
	  	Layout	=> {},
		RawData	=> [],
		Data		=> {},
		DataByWell	=> {},
		ReadOrder	=> getReadOrder(),
        };
        bless $self, $class;
	  _ParseLayoutTab($self);
	  _ParseData($self);
	  _ParseDataByWell($self);
        return $self;
}

sub getDataByRow {
	my $self=shift;
	my $row=shift;
	my $val = shift;
	my @data;
	for(my$i=1;$i<=24;$i++){
		my $wellID=$row.$i;
		if(defined($self->{DataByWell}{$wellID})){
		}else{
			die "Could not find data for well $wellID!\nALL WELLS need data - source data file malformed\n";
		}
		push @data, $self->{DataByWell}{$wellID}{$val};
	}
	return \@data;
}

sub getDataByColumn {
	my $self=shift;
	my $column=shift;
	my $val = shift;
	my @rows=("A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P");
	my @data;
	for(my$r=0;$r<=15;$r++){
		my $wellID=$rows[$r].$column;
		if(defined($self->{DataByWell}{$wellID})){
		}else{
			die "Could not find data for well $wellID!\nALL WELLS need data - source data file malformed\n";
		}
		push @data, $self->{DataByWell}{$wellID}{$val};
	}
	return \@data;
}

sub getReadOrder {
	my @rows=("A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P");
	my @order;
	for (my$r=0;$r<=15;$r++){
		my $row=$rows[$r];
		my $d=int($r/2);
		for(my $i=1;$i<=24;$i++){
			if($d == $r/2){
				push @order, $row.$i;
			}else{
				my $I=25-$i;
				push @order, $row.$I;
			}
		}
	}
	return \@order;
}

sub getDataByWell {
	my $self=shift;
	my $well=shift;
	return $self->{DataByWell}{$well};
}

sub getWellsByReadOrder {
	my $self=shift;
	return $self->{ReadOrder};
}

sub getID {
	my $self=shift;
	return $self->{ID};
}

sub getSourceListInOrder {
	my $self=shift;
	die "Cannot provide source list - no layout!\n" unless defined $self->{OrdSources};
	return $self->{OrdSources};
}

sub getSourceList {
	my $self=shift;
	my @sources=keys %{$self->{RawData}};
	return \@sources;
}

sub checkForSource {	
	my $self=shift;
	my $source=shift;
	return 1 if(defined($self->{RawData}{$source}));
	return 0;
}

sub normalizeDataBySourceByOD {
	my $self=shift;
	my $source=shift;
	my $cutoff=shift;
	my @Lum=@{$self->{RawData}{$source}{"Lum"}};
	my @OD =@{$self->{RawData}{$source}{"OD"}};
	for(my$i=0;$i<=$#Lum;$i++){
		my $value=$Lum[$i]/$OD[$i];
		if($OD[$i]<$cutoff){
			if(defined($self->{Data}{$source})){
#				push @{$self->{Data}{$source}}, -1;
			}else{
				$self->{Data}{$source}=[];
#				push @{$self->{Data}{$source}}, -1;
			}
		}else{
			if(defined($self->{Data}{$source})){
				push @{$self->{Data}{$source}}, $value;
			}else{
				$self->{Data}{$source}=[];
				push @{$self->{Data}{$source}}, $value;
			}
		}
	}
	return 1;
}

sub getNormalizedActivityBySource {
	my $self=shift;
	my $source=shift;
	if(defined($self->{Data}{$source})){
#		my $mean=Tools->mean(@{$self->{Data}{$source}});
#		return $mean;
		return $self->{Data}{$source}; ### self->Data holds the normalized values (see above);
	}else{
#		die "Could not find $source in dataset $self->{ID}!\n";
	}
	return undef;
}

sub getDataBySource {
	my $self=shift;
	my $source=shift;
	if(defined($self->{RawData}{$source})){
		return $self->{RawData}{$source};
	}else{
#		die "could not find data for source $source in well ".$self->{ID}."\n";
	}
}

sub invertLayout {
	my $self=shift;
	my $file=$self->{LayoutFile};
	my @content=@{Tools->LoadFile($file)};
	my @OrderedSources;
	my %layout;
	my $header=shift @content;
	foreach my $line (@content){
		$line=~s/\r+//;
		my @line=split(/\,/,$line);
		my $row=$line[0];
		for(my$i=1;$i<=24;$i++){
			my $source=$line[$i];
			my $well=$row.$i;
			push @OrderedSources, $source;
			if(defined($layout{$well})){
			#	push @{$layout{$source}}, $well;
				$layout{$well}=$source;
			}else{
			#	$layout{$source}=[];
			#	push @{$layout{$source}}, $well;
				$layout{$well}=$source;
			}
		}
	}
	$self->{OrdSources}=\@OrderedSources;
	$self->{Layout}=\%layout;
}

sub _ParseLayoutMatrix {
	my $self=shift;
	my $file=$self->{LayoutFile};
	my @content=@{Tools->LoadFile($file)};
	my @OrderedSources;
	my %layout;
	my $header=shift @content;
	foreach my $line (@content){
		$line=~s/\r+//;
		my @line=split(/\,/,$line);
		my $row=$line[0];
		for(my$i=1;$i<=24;$i++){
			my $source=$line[$i];
			my $well=$row.$i;
			push @OrderedSources, $source;
			if(defined($layout{$well})){
			#	push @{$layout{$source}}, $well;
				$layout{$well}=$source;
			}else{
			#	$layout{$source}=[];
			#	push @{$layout{$source}}, $well;
				$layout{$well}=$source;
			}
		}
	}
	$self->{OrdSources}=\@OrderedSources;
	$self->{Layout}=\%layout;
}

sub _ParseLayoutTab {
	my $self=shift;
	my $file=$self->{LayoutFile};
	my @content=@{Tools->LoadFile($file)};
	my @OrderedSources;
	my %layout;
	my $header=shift @content;
	foreach my $line (@content){
		$line=~s/\r+//;
		my @line=split(/\s+/,$line);
		my $source=$line[1];
		my $well=$line[0];
		push @OrderedSources, $source;
		if(defined($layout{$well})){
		#	push @{$layout{$source}}, $well;
			$layout{$well}=$source;
		}else{
		#	$layout{$source}=[];
		#	push @{$layout{$source}}, $well;
			$layout{$well}=$source;
		}
	}
	$self->{OrdSources}=\@OrderedSources;
	$self->{Layout}=\%layout;
}

sub getSourceByWell {
	my $self=shift;
	my $well=shift;
	if(defined($self->{Layout}{$well})){
		return $self->{Layout}{$well};
	}else{
		return undef;
	}
	die "Got here, impossibly.\n";
}

sub _ParseDataByWell {
	my $self=shift;
	my $file=$self->{DataFile};
#	warn $file."\n";
	my @content=@{Tools->LoadFile($file)};
	$self->{DataByWell}=\@content;
	my %data;
	foreach my $line (@content){
		$line=~s/(\r+)//g;
		my ($Well,$OD,$Lum)=(undef,0.0,0.0);
		if($line=~m/SPL/){
			$line=~s/^SPL\d+\s+//;
			($Well,$OD,$Lum)=split(/\t/,$line);
		}else{
			next unless $line=~m/[A-P]\d+\t/;
			($Well,$OD,$Lum)=split(/\t/,$line);
		}
		if(defined($Well)){
			if(defined($data{$Well})){
				$data{$Well}{"OD"} =$OD;
				$data{$Well}{"Lum"}=$Lum;
			}else{
				$data{$Well}={};
				$data{$Well}{"OD"} =$OD;
				$data{$Well}{"Lum"}=$Lum;
			}
		}else{
			die "Did not recognize data file.\n";
		}
	}
	$self->{DataByWell}=\%data;
}

sub _ParseData {
	my $self=shift;
	my $file=$self->{DataFile};
	my @content=@{Tools->LoadFile($file)};
	$self->{RawData}=\@content;
	my %data;
	foreach my $line (@content){
		$line=~s/(\r+)//g;
		my ($Well,$OD,$Lum)=(undef,0.0,0.0);
		if($line=~m/SPL/){
			$line=~s/^SPL\d+\s+//;
			($Well,$OD,$Lum)=split(/\t/,$line);
		}else{
			next unless $line=~m/[A-P]\d+\t/;
			($Well,$OD,$Lum)=split(/\t/,$line);
		}
		if(defined($Well)){
			my $source=$self->{Layout}{$Well};
			if(defined($data{$source})){
				push @{$data{$source}{"OD"}}, $OD;
				push @{$data{$source}{"Lum"}}, $Lum;
			}else{
				$data{$source}={};
				$data{$source}{"OD"}=[];
				$data{$source}{"Lum"}=[];
				push @{$data{$source}{"OD"}}, $OD;
				push @{$data{$source}{"Lum"}}, $Lum;
			}
		}else{
			next;
		}
	}
	$self->{RawData}=\%data;
}

1;
