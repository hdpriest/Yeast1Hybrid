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
use Statistics::R;

die "usage: perl $0 <config>\n\n" unless $#ARGV==0;
die "Cannot find config!\n" unless -e $ARGV[0];

my $Config = Configuration->new($ARGV[0]);
warn "checking config...\n";
checkConfig($Config);
warn "done.\n";

my $Run	=y1hRun->new();
warn "adding test sets...\n";
$Run		=_addTestSets($Config,$Run);
warn "adding control sets...\n";
$Run		=_addControlSets($Config,$Run);
warn "running test normalization...\n";
$Run->normalizeRunsByOD(.3);

warn "Checking R is accessible....\n";
my $R=Statistics::R->new();
$R->startR();
$R->send("library(ggplot2)");
warn "Done.\n";

my $oDir=$Config->get('PATHS','Output');
my $wordFile=$Config->get('PATHS','Words');
my $promoter=$Config->get('PATHS','Promoters');
my $tempDir =$Config->get('PATHS','TempDir');

warn "checking files were loaded correctly...\n";
while(my $Set=$Run->getNextTestSet()){
	my $columnFile = _genR_frame_ValuesByColumn($Set);
	my $rowFile	   = _genR_frame_ValuesByRow($Set);
	my @P=("Luminosity","OD","nAct");
	foreach my $p (@P){
		_RFrameToPNG($columnFile,"Column",$p);
		_RFrameToPNG($rowFile,"Row",$p);	
	}
}
while(my $Set=$Run->getNextCtrlSet()){
	my $columnFile = _genR_frame_ValuesByColumn($Set);
	my $rowFile	   = _genR_frame_ValuesByRow($Set);
	my @P=("Luminosity","OD","nAct");
	foreach my $p (@P){
		_RFrameToPNG($columnFile,"Column",$p);
		_RFrameToPNG($rowFile,"Row",$p);	
	}
}
warn "done.\n";
exit(0);
sub _RFrameToPNG {
	my $file =shift;
	my $group=shift;
	my $plot =shift;
	my $out=$file;
	$out=~s/csv$//;
	my $title=$out;
	$title=~s/.+\///;
	$title=~s/ByColumn//;
	$title=~s/ByRow//;
	$out.=$plot.".png";
	return 1;
}

sub _genR_frame_ValuesByRow {
	my $Set=shift;	
	my $id=$Set->getID();
	$id=~s/\.txt//;
	my @output;
	my @rows=("A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P");
	push @output, "Row,Luminosity,OD,nAct";
	for(my$r=0;$r<=$#rows;$r++){
		my $row=$rows[$r];
		my %data=%{$Set->getDataByRow($row)};
		my @Lum=@{$data{Lum}};
		my @OD=@{$data{OD}};
		for(my $n=0;$n<=$#Lum;$n++){
			my $nAct=$Lum[$n]/$OD[$n];
			my $line="$row,$Lum[$n],$OD[$n],$nAct";
			push @output, $line;
		}
	}
	my $temp=$tempDir."/".$id.".ByRow.csv";
	return $temp;
}

sub _genR_frame_ValuesByColumn {
	my $Set=shift;	
	my $id=$Set->getID();
	$id=~s/\.txt//;
	my @output;
	push @output, "Column,Luminosity,OD,nAct";
	for(my$i=1;$i<=24;$i++){
		my %data=%{$Set->getDataByColumn($i)};
		my @Lum=@{$data{Lum}};
		my @OD=@{$data{OD}};
		for(my $n=0;$n<=$#Lum;$n++){
			my $nAct=$Lum[$n]/$OD[$n];
			my $line="$i,$Lum[$n],$OD[$n],$nAct";
			push @output, $line;
		}
	}
	my $temp=$tempDir."/".$id.".ByColumn.csv";
	return $temp;
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




