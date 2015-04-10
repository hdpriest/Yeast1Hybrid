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

die "usage: perl $0 <config> <csv of control OD range> <csv of test OD range>\n\n" unless $#ARGV==2;
die "Cannot find config!\n" unless -e $ARGV[0];


my $Config = Configuration->new($ARGV[0]);
our @ctr_od_range = split(/\,/,$ARGV[1]);
our @exp_od_range = split(/\,/,$ARGV[2]);

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

$Run->normalizePlatesBySet("control",@ctr_od_range);
$Run->normalizePlatesBySet("experimental",@exp_od_range);

my @Control=@{$Run->getPlatesBySet("control")};
my @Experim=@{$Run->getPlatesBySet("experimental")};

my @Sources=@{$Run->getAllSources()};

my %Miss;
#for(my $i=0;$i<=$#Control;$i++){
#	for(my$j=$i+1;$j<=$#Control;$j++){
#		my $Ctr = $Control[$i];
#		my $Exp = $Control[$j];
#my %CtrlHist = %{_getDiffs(\@Control,\@Control)};
#my %TestHist = %{_getDiffs(\@Control,\@Experim)};
my %Data;
foreach my $Ctr (@Control){
	my %C_Ranks = %{$Ctr->getLumRanks()};
	foreach my $source (@Sources){
		if(defined($C_Ranks{$source})){
			my $rank = $C_Ranks{$source};
			if(defined($Data{$source})){
				push @{$Data{$source}},$rank;
			}else{
				$Data{$source}=[];
				push @{$Data{$source}},$rank;
			}
		}else{
		}
	}
}
my %DataE;
foreach my $Exp (@Experim){
	my %E_Ranks = %{$Exp->getLumRanks()};
	foreach my $source (@Sources){
		if(defined($E_Ranks{$source})){
			my $rank = $E_Ranks{$source};
			if(defined($DataE{$source})){
				push @{$DataE{$source}},$rank;
			}else{
				$DataE{$source}=[];
				push @{$DataE{$source}},$rank;
			}
		}else{
		}
	}
}
foreach my $s (sort {$a cmp $b} @Sources){
	next unless defined $Data{$s};
	next unless defined $DataE{$s};
	print $s."\t".join(";",@{$Data{$s}})."\t".join(";",@{$DataE{$s}})."\n";
}


sub _getCutoff{
	my %ctrl = %{$_[0]};
	my %test = %{$_[1]};
	my %Totals;
	for(my$i=0;$i<=384;$i++){
		$Totals{$i}={};
		$Totals{$i}{ctrl}=0;
		$Totals{$i}{test}=0;
		for(my $j=$i;$j<=384;$j++){
			if(defined($ctrl{$j})){
				$Totals{$i}{ctrl}+=$ctrl{$j};
			}
			if(defined($test{$j})){
				$Totals{$i}{test}+=$test{$j};
			}
		}
	}
	for(my$i=0;$i<=384;$i++){
		next if ($Totals{$i}{test}==0);
		if (($Totals{$i}{ctrl}!=0)||($Totals{$i}{test}!=0)){
			my $FDR=$Totals{$i}{ctrl}/$Totals{$i}{test};
			print $i."\t".$Totals{$i}{test}."\t".$Totals{$i}{ctrl}."\t".$FDR."\n";
		}
	}
	return 0;
}

sub _getDiffs {
	my @Control = @{$_[0]};
	my @Experim = @{$_[1]};
	my %done;
	my %Data;
	my $comps=0;
	for(my $i=0;$i<=$#Control;$i++){		
		for(my$j=0;$j<=$#Experim;$j++){
			my $Ctr = $Control[$i];
			my $Exp = $Experim[$j];
			my $IDC = $Ctr->getID();
			my $IDE = $Exp->getID();
			next if $IDC eq $IDE;
			my @k=sort {$a cmp $b} ($IDC,$IDE);
			my $key = join(",",@k);
			next if defined($done{$key});
			$done{$key}=1;
			$comps++;
			my %C_Ranks = %{$Ctr->getLumRanks()};
			my %E_Ranks = %{$Exp->getLumRanks()};
			foreach my $Source (@Sources){
				next unless defined $C_Ranks{$Source};
				next unless defined $E_Ranks{$Source};
				my $diff = abs($C_Ranks{$Source}-$E_Ranks{$Source});
				$Data{$diff}+=1;
			}
		}
	}
	warn "Made $comps comparisons\n";
	#foreach my $diff (keys %Data){
	#	$Data{$diff}= $Data{$diff}/$comps;
	#}
	return \%Data;
}

