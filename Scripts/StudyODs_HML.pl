#!/usr/bin/perl
use warnings;
use strict;
use lib '/home/hpriest/Scripts/Library';
use Y1H::y1hRun;
use hdpTools;
use Configuration;


die "usage: perl $0 <config>\n\n" unless $#ARGV==0;
die "Cannot find config!\n" unless -e $ARGV[0];

my $Config = Configuration->new($ARGV[0]);
checkConfig($Config);

my $Run	=y1hRun->new();
$Run		=_addControlSets($Config,$Run);
my $oDir=$Config->get('PATHS','Output');
my @Sources=@{$Run->getAllSources()};
print "Source,OD,exp\n";
foreach my $source (@Sources){
#	warn $source."\n";
	my %d		=%{$Run->getControlDataBySource($source)};
	my @cod	=@{$d{"C"}{"OD"}};
	my @clum	=@{$d{"C"}{"Lum"}};
	my @CIDs	=@{$d{"C"}{"IDS"}};
	#my $maxCod	=hdpTools->Max(@cod);
	#my $maxClum	=hdpTools->Max(@clum);
	for(my$i=0;$i<=$#CIDs;$i++){
		my $ID=$CIDs[$i];
		my $date=$Config->get('DATES',$ID);
		print $source.",".$cod[$i].",".$date."\n";
	}
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




