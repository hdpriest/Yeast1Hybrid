#!/usr/bin/perl
use warnings;
use strict;
use FindBin;
use lib "$FindBin::Bin/../../Lib";
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

my @Plates=@{$Run->getPlatesBySet("control")};
foreach my $plate (@Plates){
	my $ID = $plate->getID();
	die "Cannot find cutoffs for $ID\n\n" unless $Config->get('CUTOFFS',$ID);
	my @range=split(/,/,$Config->get('CUTOFFS',$ID));
	$plate->normalizeDataByOD(@range);
}
@Plates=@{$Run->getPlatesBySet("experimental")};
foreach my $plate (@Plates){
	my $ID = $plate->getID();
	die "Cannot find cutoffs for $ID\n\n" unless $Config->get('CUTOFFS',$ID);
	my @range=split(/,/,$Config->get('CUTOFFS',$ID));
	$plate->normalizeDataByOD(@range);
}


my @Control=@{$Run->getPlatesBySet("control")};
my @Experim=@{$Run->getPlatesBySet("experimental")};

my @Sources=@{$Run->getAllSources()};

my %Data;
my %Miss;
#for(my $i=0;$i<=$#Control;$i++){
#	for(my$j=$i+1;$j<=$#Control;$j++){
#		my $Ctr = $Control[$i];
#		my $Exp = $Control[$j];
#my %CtrlHist = %{_getDiffs(\@Control,\@Control)};
#my %TestHist = %{_getDiffs(\@Control,\@Experim)};
my %TestHist = %{_getDiffsBySource(\@Control,\@Experim)};
my %CtrlHist = %{_getDiffsBySource(\@Control,\@Control)};

my $cutoff=10;
my $hit=0;
my $totHit=0;
my $miss=0;
foreach my $s (@Sources){
	next unless defined $TestHist{$s};
	next unless defined $CtrlHist{$s};
	my $cm = Tools->mean(@{$CtrlHist{$s}});
	my $tm = Tools->mean(@{$TestHist{$s}});
	next if scalar(@{$CtrlHist{$s}}) < 3;
#	print $P{$s}."\n";
#	my $cstring = "Control: ".$s."\t".$cm."\t".join(",",@{$CtrlHist{$s}});
#	my $tstring = "Test: ".$s."\t".$tm."\t".join(",",@{$TestHist{$s}});
#	print $cstring."\n".$tstring."\n"."\n";
	my $D = $tm-$cm;
#	print $D."\t".$s."\n";
	next unless defined $P{$s};
	if($D>$cutoff){
#		print ">$s\n$P{$s}\n";
		$totHit++;
		print ">".$s."\n".$P{$s}."\n";
		next unless(($P{$s}=~m/G.ATC/) || ($P{$s}=~m/GAT.C/));
		$hit++;
	}else{
		next unless(($P{$s}=~m/G.ATC/) || ($P{$s}=~m/GAT.C/));
		$miss++;
	}
#	warn $s."\n" if ($P{$s}=~m/GAT.C/);
}
warn "Total hit (diff above $cutoff):$totHit\n";

#my $Cut=_getCutoff(\%CtrlHist,\%TestHist);

exit(0);

for(my$r=0;$r<=384;$r++){
	my $line=$r;
	if(defined($CtrlHist{$r})){
		$line.="\t$CtrlHist{$r}";
	}else{
		$line.="\t0";
	}
	if(defined($TestHist{$r})){
		$line.="\t$TestHist{$r}";
	}else{
		$line.="\t0";
	}
	next if $line=~m/\t0\t0$/;
	print $line."\n";
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

sub _getDiffsBySource {
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
			warn "Comparing $IDC with $IDE\n";
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
				my $diff = $C_Ranks{$Source}-$E_Ranks{$Source};
				if(defined($Data{$Source})){
					push @{$Data{$Source}}, $diff;
				}else{
					$Data{$Source}=[];
					push @{$Data{$Source}}, $diff;
				}
			}
		}
	}
	warn "Made $comps comparisons\n";
	#foreach my $diff (keys %Data){
	#	$Data{$diff}= $Data{$diff}/$comps;
	#}
	return \%Data;
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

