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
my @Barcodes = @{Tools->LoadFile($iDir."/".$barcodes)};
my $Run = y1hRun->new();
$Run->parseExperiment($Config,\@Barcodes);

warn "Starting R...\n";
my $R=Statistics::R->new();
$R->startR();
$R->send("library(ggplot2)");
warn "Done.\n";

my %s;

while(my $Plate=$Run->getNextPlate()){
	my $ID = $Plate->getID();
	warn "Processing $ID\n";
	my @SL = @{$Plate->getSourceListInOrder()};
	my %Sources;
	map {$Sources{$_}=1} @SL;
	foreach my $s (keys %Sources){
		warn "Processing source: $s\n";
		my @OD = @{$Plate->getODBySource($s)};
		my @Lum= @{$Plate->getLumBySource($s)};
		if(defined($s{$s})){ ### don't do this
			for(my$i=0;$i<=$#OD;$i++){
				my $od=sprintf("%.2f",$OD[$i]);
				if(defined($s{$s}{$od})){
					push @{$s{$s}{$od}}, $Lum[$i];
				}else{
					$s{$s}{$od}=[];
					push @{$s{$s}{$od}}, $Lum[$i];
				}
			}
		}else{
			$s{$s}={};
			for(my$i=0;$i<=$#OD;$i++){
				my $od=sprintf("%.2f",$OD[$i]);
				if(defined($s{$s}{$od})){
					push @{$s{$s}{$od}}, $Lum[$i];
				}else{
					$s{$s}{$od}=[];
					push @{$s{$s}{$od}}, $Lum[$i];
				}
			}
		}
	}
}

foreach my $s (keys %s){
	my $tfile = _genR_frame_PerSource($s{$s},$barcodes);
	_RFrameToPNG($tfile,"OD","Lum");
}




exit(0);

sub _RFrameToPNG {
	my $file =shift;
	my $group=shift;
	my $plot =shift;
	my $out=$file;
	$out=~s/csv$//;
	my $title=$out;
	$title=~s/.+\///;
#	$title=~s/ByColumn//;
#	$title=~s/ByRow//;
	$out.=$plot.".png";
	my $cmd="DF=as.data.frame(read.table(\"$file\",sep=\",\",header=TRUE))";
	#warn "$cmd\n";
	$R->send($cmd);
	$cmd="png(file=\"$out\",height=1200,width=1200,units=\"px\")";
	#warn "$cmd\n";
	$R->send($cmd);
#	png(file="test.png",width=1200,height=1200,units="px")
#	> ggplot(data=DF,aes(x=OD,y=Lum,group=OD)) + geom_boxplot()
	$cmd="ggplot(data=DF,aes(x=$group,y=$plot,group=$group)) + geom_boxplot() + theme(axis.text.x = element_text(angle=90,hjust=1)) + ggtitle(\"$title\")";
	#warn "$cmd\n";
	$R->send($cmd);
	$cmd="dev.off()";
	$R->send($cmd);
	return 1;
}

sub _genR_frame_PerSource {
	my %data = %{$_[0]};
	my $id = $_[1];
	my @output;
	push @output, "OD,Lum";
	foreach my $od (sort {$a <=> $b} keys %data){
		my @lum = @{$data{$od}};
		for(my$i=0;$i<=$#lum;$i++){
			my $line = $od.",".$lum[$i];
			push @output, $line;
		}
	}
	my $temp=$oDir."/".$id.".LumByOD.csv";
	Tools->printToFile($temp,\@output);
	return $temp;
}

sub checkConfig {
	my $Config=shift;
	warn "skipping config check\n";
	return 1;
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




