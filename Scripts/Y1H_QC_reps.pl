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
checkConfig($Config);
my $Run	=y1hRun->new();
$Run		=_addTestSets($Config,$Run);
$Run		=_addControlSets($Config,$Run);
$Run->normalizeRunsByOD(.3);

warn "Starting R...\n";
my $R=Statistics::R->new();
$R->startR();
$R->send("library(ggplot2)");
warn "Done.\n";

my $oDir=$Config->get('PATHS','Output');
my $wordFile=$Config->get('PATHS','Words');
my $promoter=$Config->get('PATHS','Promoters');
my $tempDir =$Config->get('PATHS','TempDir');

foreach my $rep ($Config->getAll('REPS')){
	my $file=_genR_frame_ValuesByIDs($Config,$Run,$rep);
	my ($f1,$f2)=split(/\,/,$Config->get('REPS',$rep));
	my @parts1=split(/\_/,$f1);
	my @parts2=split(/\_/,$f2);
	my $t1=$parts1[0]."-".$parts1[1];
	my $t2=$parts2[0]."-".$parts2[1];
	my @values=("Lum","OD","nAct");
	foreach my $value (@values){
		_RFrameToPNG_scatter($file,$value,$t1,$t2,$rep);
	}
}

sub _RFrameToPNG_scatter {
	my $file =shift;
	my $plot =shift;
	my $l1=shift;
	my $l2=shift;
	my $repNo=shift;
	my $out=$file;
	$out=~s/csv$//;
	my $title="rep $repNo: ".$l1 ." vs ".$l2." $plot";
	$out.=$plot.".png";
	my $cmd="DF=as.data.frame(read.table(\"$file\",sep=\",\",header=TRUE))";
	$R->send($cmd);
#	warn $cmd;
	$cmd="png(file=\"$out\")";
	$R->send($cmd);
#	warn $cmd;
	my $v1=$plot."1";
	my $v2=$plot."2";

	$cmd="ggplot(data=DF,aes(x=$v1,y=$v2)) + geom_point(shape=1) + ggtitle(\"$title\") + xlab(\"$l1\") + ylab(\"$l2\")";
#	warn $cmd;
	$cmd.=" + geom_abline(slope=1, intercept=0)" unless $plot =~ m/od/i;
	$R->send($cmd);
	$cmd="dev.off()";
#	warn $cmd;
	$R->send($cmd);
	return 1;
}

sub _genR_frame_ValuesByIDs {
	my $Config=shift;
	my $Run=shift;
	my $rep=shift;
	my ($id1,$id2)=split(/\,/,$Config->get('REPS',$rep));
	my $set1=$Run->getSetByID($id1);
	my $set2=$Run->getSetByID($id2);
	my @Order=@{$set1->getWellsByReadOrder()};
	my @output;
	push @output, "RepID,well,source,Lum1,OD1,nAct1,Lum2,OD2,nAct2";
	my @rows=("A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P");
	my @sources=@{$set1->getSourceListInOrder()};
	for(my$i=0;$i<=$#Order;$i++){
#	foreach my $well (@Order){
		my $well=$Order[$i];
		my $source=$sources[$i];
		my %d1=%{$set1->getDataByWell($well)};
		my %d2=%{$set2->getDataByWell($well)};
		my $na1=$d1{Lum}/$d1{OD};
		my $na2=$d2{Lum}/$d2{OD};
		my $line = $rep.",".$well.",".$source.",".$d1{Lum}.",".$d1{OD}.",".$na1.",".$d2{Lum}.",".$d2{OD}.",".$na2;
		push @output, $line;
		
	}
	my $temp=$tempDir."/Rep.".$rep.".scatter.csv";
	hdpTools->printToFile($temp,\@output);
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




