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

sub getDataByQuadrant {
	my $self=shift;
	my $val = shift;
	my @Q23 =("B","D","F","H","J","L","N","P");
	my @Q14 =("A","C","E","G","I","K","M","O");
	my %data;
	$data{Q1}=[];
	$data{Q2}=[];
	$data{Q3}=[];
	$data{Q4}=[];
	for(my $i=1;$i<=23;$i+=2){
		my $q13 = $i;
		my $q24 = $i+1;
		foreach my $r (@Q14){
			my $w1 = $r.$q13;
			my $w4 = $r.$q24;
			push @{$data{Q1}}, $self->{DataByWell}{$w1}{$val};
			push @{$data{Q4}}, $self->{DataByWell}{$w4}{$val};
		}
		foreach my $r (@Q23){
			my $w2 = $r.$q13;
			my $w3 = $r.$q24;
			push @{$data{Q2}}, $self->{DataByWell}{$w2}{$val};
			push @{$data{Q3}}, $self->{DataByWell}{$w3}{$val};
		}
	}
	return \%data;
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

sub normalizeDataByOD {
	my $self= shift;
	my $low = shift;
	my $high= shift;
	my @sources =@{$self->{OrdSources}};
	foreach my $source (@sources){
		my @Lum=@{$self->{RawData}{$source}{"Lum"}};
		my @OD =@{$self->{RawData}{$source}{"OD"}};
		for(my$i=0;$i<=$#Lum;$i++){
		#	my $value=$Lum[$i]/$OD[$i];
			my $value=$Lum[$i];
			if(($OD[$i] > $low) && ($OD[$i] < $high)){
				if(defined($self->{Data}{$source})){
#					push @{$self->{Data}{$source}}, -1;
					push @{$self->{Data}{$source}}, $value;
				}else{
					$self->{Data}{$source}=[];
					push @{$self->{Data}{$source}}, $value;
#					push @{$self->{Data}{$source}}, -1;
				}
			}else{
				if(defined($self->{Data}{$source})){
				}else{
					$self->{Data}{$source}=[];
				}
			}
		}
	}
	return 1;
}

sub getLums {
	my $self=shift;
	my %Lum;
	my @sources = @{$self->{OrdSources}};
	foreach my $s (@sources){
		if(defined($self->{Data}{$s})){
			my @L = @{$self->{Data}{$s}};
			next if defined $Lum{$s};
			$Lum{$s}=\@L;
			print join("\n",@L)."\n";
	last;
			for(my $x=0;$x<=$#L;$x++){
				my $L=$L[$x];
				if(defined($Lum{$s})){
					push @{$Lum{$s}}, $L;
				}else{
					push @{$Lum{$s}}, $L;
				}
			}
		}
	}
	exit;
	return \%Lum;
}

sub getLumRanks {
	my $self=shift;
	my %Ranks;
	my %R;
	my @sources = @{$self->{OrdSources}};
	foreach my $s (@sources){
		if(defined($self->{Data}{$s})){
			my @L = @{$self->{Data}{$s}};
			for(my $x=0;$x<=$#L;$x++){
				my $L=$L[$x];
				if(defined($R{$L})){
					push @{$R{$L}}, $s;
				}else{
					$R{$L}=[];
					push @{$R{$L}}, $s;
				}
			}
		}else{
			warn "undefined $s\n";
			return undef;
		}
	}
	my @R_i = sort {$a <=> $b} keys %R;
	my $rank=0;
	for(my $i=0;$i<=$#R_i;$i++){
		my @source_list = @{$R{$R_i[$i]}};
		foreach my $s (@source_list){
			$rank+=1;
			if(defined($Ranks{$s})){
				push @{$Ranks{$s}}, $rank;
			}else{
				$Ranks{$s}=[];
				push @{$Ranks{$s}}, $rank;
			}
		}
	}
	return \%Ranks;
}

sub normalizeDataBySourceByOD {
	my $self=shift;
	my $source=shift;
	my $low=shift;
	my $high=shift;
	my @Lum=@{$self->{RawData}{$source}{"Lum"}};
	my @OD =@{$self->{RawData}{$source}{"OD"}};
	for(my$i=0;$i<=$#Lum;$i++){
	#	my $value=$Lum[$i]/$OD[$i];
		my $value=$Lum[$i];
		if(($OD[$i] > $low) && ($OD[$i] < $high)){
			if(defined($self->{Data}{$source})){
#				push @{$self->{Data}{$source}}, -1;
				push @{$self->{Data}{$source}}, $value;
			}else{
				$self->{Data}{$source}=[];
				push @{$self->{Data}{$source}}, $value;
#				push @{$self->{Data}{$source}}, -1;
			}
		}else{
			if(defined($self->{Data}{$source})){
			}else{
				$self->{Data}{$source}=[];
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

sub getLumBySource {
	my $self=shift;
	my $source=shift;
	if(defined($self->{RawData}{$source})){
		return $self->{RawData}{$source}{Lum};
	}else{
		return undef;
	}
}

sub getODBySource {
	my $self=shift;
	my $source=shift;
	if(defined($self->{RawData}{$source})){
		return $self->{RawData}{$source}{OD};
	}else{
		return undef;
	}
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
	die "Cannot find layout file.\n" unless -e $file;
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
			my $source;
			if(defined($self->{Layout}{$Well})){
				$source=$self->{Layout}{$Well};
			}else{
				die "Could not find a source for $Well\n";
			}
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
