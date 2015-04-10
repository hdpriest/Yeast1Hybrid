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

die "usage: perl $0 <config> <csv of control OD range> <csv of test OD range>\n\n" unless $#ARGV==2;
die "Cannot find config!\n" unless -e $ARGV[0];

my $Config = Configuration->new($ARGV[0]);
my @ctr_od_range = split(/\,/,$ARGV[1]);
my @exp_od_range = split(/\,/,$ARGV[2]);
my $EXID=$Config->get('OPTIONS',"ID");
my $oDir=$Config->get('PATHS','Output');
my $iDir=$Config->get('PATHS','DataDir');
my $wordFile=$Config->get('PATHS','Words');
my $promoter=$Config->get('PATHS','Promoters');
my $tempDir =$Config->get('PATHS','TempDir');
my $barcodes=$Config->get('PATHS','Barcodes');
my $cutRatio=$Config->get('OPTIONS','OD_cutRatio');
my @Barcodes = @{Tools->LoadFile($iDir."/".$barcodes)};
my %P = %{Tools->LoadFasta($promoter)};
my $Run = y1hRun->new();
$Run->parseExperiment($Config,\@Barcodes);
my $WO=WordManager->new($wordFile,$promoter,$tempDir);

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
			next unless defined $P{$Source};
			$Ctr->normalizeDataBySourceByOD($Source,$ctr_od_range[0],$ctr_od_range[1]);
			$Exp->normalizeDataBySourceByOD($Source,$exp_od_range[0],$exp_od_range[1]);
			my @C = @{$Ctr->getNormalizedActivityBySource($Source)};
			my @E = @{$Exp->getNormalizedActivityBySource($Source)};
			next unless scalar(@C) > 0;
			next unless scalar(@E) > 0;
			my @D = @{getAllDifferences(\@E,\@C)};
			if(defined($Data{$Source})){
				map {push @{$Data{$Source}{"Test"}}, $_} @E;
				map {push @{$Data{$Source}{"Ctrl"}}, $_} @C;
			}else{
				$Data{$Source}={};
				$Data{$Source}{"Test"}=\@E;
				$Data{$Source}{"Ctrl"}=\@C;
			}
		}
	}
}

foreach my $source (keys %Data){
	my @Control;
	my @Test;
	map {push @Control, $_} @{$Data{$source}{"Ctrl"}};
	map {push @Test, $_} @{$Data{$source}{"Test"}};
	my @cD=@{getAllDifferences(\@Control,\@Control)};
	my @tD=@{getAllDifferences(\@Test,\@Control)};
	next unless scalar(@cD) > 5;
	next unless scalar(@tD) > 5;
	warn join(",",@cD)."\t".join(",",@tD)."\n";
	my $wilcox_test=Statistics::Test::WilcoxonRankSum->new();
	$wilcox_test->load_data(\@cD,\@tD);
	my $ret=$wilcox_test->probability();
	print $source."\t".$ret."\n";
}

sub getAllDifferencesAsHistogram {
	my @a1=@{$_[0]};
	my @a2=@{$_[1]};
	my @D;
	my %H;
	for(my$i=0;$i<=$#a1;$i++){
		for(my$j=0;$j<=$#a2;$j++){
			my $d=$a1[$i]-$a2[$j];
			next if $d==0;
			$d=$d/100;
			my $D = sprintf("%.2f", $d);
			$H{$D}+=1;
			push @D, $d;
		}
	}
	return \%H;
}

sub getAllDifferences {
	my @a1=@{$_[0]};
	my @a2=@{$_[1]};
	my @D;
	for(my$i=0;$i<=$#a1;$i++){
		for(my$j=0;$j<=$#a2;$j++){
			my $d=$a1[$i]-$a2[$j];
			next if $d==0;
			push @D, $d;
		}
	}
	return \@D;
}

sub checkHitMean {
	my @Control	=@{$_[0]};
	my @Test	=@{$_[1]};
	my $cut	=$_[2];
	my $cm=Tools->mean(@Control);
	my $tm=Tools->mean(@Test);
	my $tml2=Tools->log2($tm);
	my $cml2=Tools->log2($cm);
	if(($tml2-$cml2)<$cut){
		return 0;
	}else{
		return 1;
	}
}

sub checkHit {
	my @Control	=@{$_[0]};
	my @Test	=@{$_[1]};
	my $cut	=$_[2];
	return 0 unless defined $Test[0];
	foreach my $test (@Test){
		return 0 unless defined $Control[0];
		foreach my $control (@Control){
			my $tl2=Tools->log2($test);
			my $cl2=Tools->log2($control);
			my $D=$tl2-$cl2;
			if($D<$cut){
				return 0;
			}
		}
	}
	return 1;
}

