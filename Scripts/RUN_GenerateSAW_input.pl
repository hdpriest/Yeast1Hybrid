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

die "usage: perl $0 <config>\n\n" unless $#ARGV==0;
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
	for(my$j=0;$j<=$#Experim;$j++){
		my $Ctr = $Control[$i];
		my $Exp = $Experim[$j];
		foreach my $Source (@Sources){
			## Not all plates have all sources - we have two racks
			## Skip all plate combos which don't have common sources
			## Either Lazy or Smart
			next unless $Ctr->checkForSource($Source);
			next unless $Exp->checkForSource($Source);
			$Ctr->normalizeDataBySourceByOD($Source,0);
			$Exp->normalizeDataBySourceByOD($Source,0);
			my @C = @{$Ctr->getNormalizedActivityBySource($Source)};
			my @E = @{$Exp->getNormalizedActivityBySource($Source)};
			my @D = @{getAllDifferences(\@E,\@C)};
			if(defined($P{$Source})){
				foreach my $d (@D){
					if(defined($Data{$d})){
						push @{$Data{$d}},$Source;
					}else{
						$Data{$d}=[];
						push @{$Data{$d}},$Source;
					}
				}
			}else{
	#			warn "Cannot find sequence for $Source!\nPromoters:$promoter\n";
				$Miss{$Source}=1;			
			}
		}
	}
}
warn scalar(keys(%Miss))." promoters not found in file: $promoter\n";
map {warn $_."\n"} keys %Miss;

foreach my $key (sort {$b <=> $a} keys %Data){
	my @d=@{$Data{$key}};
	foreach my $d(@d){
		print $key."\t".$P{$d}."\n";
	}
}

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

