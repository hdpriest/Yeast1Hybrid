#!/usr/bin/perl
use warnings;
use strict;
use lib '/home/hpriest/Scripts/Library';
use Y1H::y1hRun;
use Y1H::WordManager;
use hdpTools;
use Configuration;
use Statistics::Multtest qw(:all);
use Statistics::Test::WilcoxonRankSum;

die "usage: perl $0 <config>\n\n" unless $#ARGV==0;
die "Cannot find config!\n" unless -e $ARGV[0];

my $Config = Configuration->new($ARGV[0]);
checkConfig($Config);
my $Run	=y1hRun->new();
$Run		=_addTestSets($Config,$Run);
$Run		=_addControlSets($Config,$Run);
$Run->normalizeRunsByOD(.3);

my $oDir=$Config->get('PATHS','Output');
my $wordFile=$Config->get('PATHS','Words');
my $promoter=$Config->get('PATHS','Promoters');
my $tempDir =$Config->get('PATHS','TempDir');
my $WO=WordManager->new($wordFile,$promoter,$tempDir);
my %P=%{hdpTools->LoadFasta($promoter)};
my @Sources=@{$Run->getAllSources()};
my %Data;

my @Pairings=$Config->getAll('REPS');
foreach my $pair (@Pairings){
	my ($C,$T)=split(/\,/,$Config->get('REPS',$pair));
	my $ctrl=$Run->getSetByID($C);
	my $test=$Run->getSetByID($T);
	foreach my $Source (@Sources){
	#	next unless $Source eq "R3-E1";
		next unless $ctrl->checkForSource($Source);
		next unless $test->checkForSource($Source);
		$ctrl->normalizeDataBySourceByOD($Source,0);
		$test->normalizeDataBySourceByOD($Source,0);
		my @t=@{$test->getNormalizedActivityBySource($Source)};
		my @c=@{$ctrl->getNormalizedActivityBySource($Source)};
		my @ds=@{getAllDifferences(\@t,\@c)};
#		print "$pair\t$C\t$T\n";
#		print join(",",@t)."\n";
#		print join(",",@c)."\n";
#		print join(",",@ds)."\n\n";
		if(defined($P{$Source})){
			foreach my $d (@ds){
				if(defined($Data{$d})){
					push @{$Data{$d}},$Source;
				}else{
					$Data{$d}=[];
					push @{$Data{$d}},$Source;
				}
			}
		}else{
			warn "Cannot find sequence for $Source!\nPromoters:$promoter\n";
		}
	}
}

foreach my $key (sort {$b <=> $a} keys %Data){
	my @d=@{$Data{$key}};
	foreach my $d(@d){
		print $key."\t".$P{$d}."\n";
	}
}

sub getAllDifferencesLog2 {
	my @a1=@{$_[0]};
	my @a2=@{$_[1]};
	my @D;
	for(my$i=0;$i<=$#a1;$i++){
		for(my$j=0;$j<=$#a2;$j++){
			my $d=hdpTools->log2($a1[$i])-hdpTools->log2($a2[$j]);
			next if $d==0;
			push @D, $d;
		}
	}
	return \@D;
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

sub checkHitMean {
	my @Control	=@{$_[0]};
	my @Test	=@{$_[1]};
	my $cut	=$_[2];
	my $cm=hdpTools->mean(@Control);
	my $tm=hdpTools->mean(@Test);
	my $tml2=hdpTools->log2($tm);
	my $cml2=hdpTools->log2($cm);
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
			my $tl2=hdpTools->log2($test);
			my $cl2=hdpTools->log2($control);
			my $D=$tl2-$cl2;
			if($D<$cut){
				return 0;
			}
		}
	}
	return 1;
}

sub _addControlSets {
	my $Config	=shift;
	my $Run	=shift;
	warn "Adding control datasets\n";
	foreach my $file ($Config->getAll('CONTROLFILES')){
		my $DataPath	=$Config->get('PATHS','DataDir')."/".$file;
		my $layout 		=$Config->get('CONTROLFILES',$file);
		my $LayoutPath	=$Config->get('PATHS','DataDir')."/".$Config->get('LAYOUTS',$layout);
		$Run->addControlSet($DataPath,$LayoutPath,$file);
	}
	return $Run;
}

sub _addTestSets {
	my $Config	=shift;
	my $Run	=shift;
	warn "Adding test datasets\n";
	foreach my $file ($Config->getAll('TESTFILES')){
		my $DataPath	=$Config->get('PATHS','DataDir')."/".$file;
		my $layout 		=$Config->get('TESTFILES',$file);
		my $LayoutPath	=$Config->get('PATHS','DataDir')."/".$Config->get('LAYOUTS',$layout);
		$Run->addTestSet($DataPath,$LayoutPath,$file);
	}
	return $Run;
}

sub checkConfig {
	my $Config=shift;
	warn "Checking Config.\n";
	die "Data directory undefined in config file!\n" unless(-e $Config->get('PATHS','DataDir'));
	die "Promoter file undefined in config file!\n" unless(-e $Config->get('PATHS','Promoters'));
	die "Output directory undefined in config file!\n" unless(-e $Config->get('PATHS','Output'));
	my @Layouts=$Config->getAll('LAYOUTS');
	die "No layouts defined!\n" unless (scalar(@Layouts)>0);
	foreach my $layout ($Config->getAll('LAYOUTS')){
		my $file=$Config->get('LAYOUTS',$layout);
		my $path=$Config->get('PATHS','DataDir')."/".$file;
		die "Cannot find $path\n" unless -e $path;
	}
	
	my @Tests=$Config->getAll('TESTFILES');
	die "No testfiles defined!\n" unless (scalar(@Tests)>0);
	foreach my $test ($Config->getAll('TESTFILES')){
		my $layout=$Config->get('LAYOUTS',$test);
		die "Cannot find layout for test file $test!\n" unless $layout; # $Config->get on an empty entry returns -1
		my $path=$Config->get('PATHS','DataDir')."/".$test;
		die "Cannot find $path\n" unless -e $path;
	}

	my @Controls=$Config->getAll('CONTROLFILES');
	die "No Controlfiles defined!\n" unless(scalar(@Controls)>0);
	foreach my $ctrl ($Config->getAll('CONTROLFILES')){
		my $layout=$Config->get('LAYOUTS',$ctrl);
		die "Cannot find layout for test file $ctrl!\n" unless $layout;
		my $path=$Config->get('PATHS','DataDir')."/".$ctrl;
		die "Cannot find $path\n" unless -e $path;
	}
	warn "Config checks out\n";
	return 1;
}




