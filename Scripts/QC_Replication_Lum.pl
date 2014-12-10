#!/usr/bin/perl
use warnings;
use strict;
use FindBin;
use lib "$FindBin::Bin/../Lib";
use y1hRun;
use y1hPlate;
use WordManager;
use Tools;
use Configuration;
use Statistics::Multtest qw(:all);
use Statistics::Test::WilcoxonRankSum;
use Statistics::R;

die "usage: perl $0 <config> <Experiment label>\n\n" unless $#ARGV==1;
die "Cannot find config!\n" unless -e $ARGV[0];


my $Config = Configuration->new($ARGV[0]);
my $oDir=$Config->get('PATHS','Output');
my $iDir=$Config->get('PATHS','DataDir');
my $wordFile=$Config->get('PATHS','Words');
my $promoter=$Config->get('PATHS','Promoters');
my $tempDir =$Config->get('PATHS','TempDir');
my $barcodes=$Config->get('PATHS','Barcodes');

my %P = %{Tools->LoadFasta($promoter)};
my @Barcodes = @{Tools->LoadFile($iDir."/".$barcodes)};
my $Run = y1hRun->new();
$Run->parseExperiment($Config,\@Barcodes);

my @Control=@{$Run->getPlatesBySet("control")};
my @Experim=@{$Run->getPlatesBySet("experimental")};

my @Sources=@{$Run->getAllSources()};

my %Data;
my %Miss;
for(my $i=0;$i<=$#Control;$i++){
	my $Ctr = $Control[$i];
	foreach my $Source (@Sources){
		next unless $Ctr->checkForSource($Source);
		$Ctr->normalizeDataBySourceByOD($Source,0);
		my @C = @{$Ctr->getNormalizedActivityBySource($Source)};
		if(defined($P{$Source})){
			map {push @{$Data{$Source}}, $_} @C;
		}else{
			$Data{$Source}=[];
			map {push @{$Data{$Source}}, $_} @C;
		}
	}
}
my $out = $ARGV[1].".ctrl.txt";
my @out;
foreach my $s (keys %Data){
	my @d = @{$Data{$s}};
	foreach my $e (@d){
		my $line = $ARGV[1].",control,$e\n";
		push @out, $line;
	}
}
hdpTools->printToFile($out,\@out);
$out = $ARGV[1].".exp.txt";
@out =();
%Data={};
for(my$j=0;$j<=$#Experim;$j++){
	my $Exp = $Experim[$j];
	foreach my $Source (@Sources){
		next unless $Exp->checkForSource($Source);
		my @E = @{$Exp->getNormalizedActivityBySource($Source)};
		if(defined($P{$Source})){
			map {push @{$Data{$Source}}, $_} @E;
		}else{
			$Data{$Source}=[];
			map {push @{$Data{$Source}}, $_} @E;
		}
	}
}
foreach my $s (keys %Data){
	my @d = @{$Data{$s}};
	foreach my $e (@d){
		my $line = $ARGV[1].",test,$e\n";
		push @out, $line;
	}
}
hdpTools->printToFile($out,\@out);


sub getAllDifferences {
	my @a1=@{$_[0]};
	my @a2=@{$_[1]};
	my @D;
	for(my$i=0;$i<=$#a1;$i++){
		for(my$j=0;$j<=$#a2;$j++){
			my $d=$a1[$i]/$a2[$j];
			next if $d==0;
			push @D, $d;
		}
	}
	return \@D;
}

