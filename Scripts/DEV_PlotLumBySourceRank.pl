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

my $R=Statistics::R->new();
$R->startR();
$R->send("library(ggplot2)");

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

my %Data;
for(my $i=0;$i<=$#Control;$i++){
	my %Ranks = %{$Control[$i]->getLumRanks()};
	foreach my $s (@Sources){
		next unless defined $Ranks{$s};
		if(defined($Data{$s})){
			push @{$Data{$s}{'c'}}, $Ranks{$s};
		}else{
			$Data{$s}={};
			$Data{$s}{'c'}=[];
			$Data{$s}{'e'}=[];
			push @{$Data{$s}{'c'}}, $Ranks{$s};
		}
	}
}
for(my $j=0;$j<=$#Experim;$j++){
	my %Ranks = %{$Experim[$j]->getLumRanks()};
	foreach my $s (@Sources){
		next unless defined $Ranks{$s};
		if(defined($Data{$s})){
			push @{$Data{$s}{'e'}}, $Ranks{$s}
		}else{
			$Data{$s}={};
			$Data{$s}{'e'}=[];
			push @{$Data{$s}{'e'}}, $Ranks{$s};
		}
	}
}


foreach my $source (keys %Data){
	next unless defined $Data{$source}{'c'}; 
	next unless defined $Data{$source}{'e'}; 
	next unless scalar(@{$Data{$source}{'e'}}) >= 4;
	next unless scalar(@{$Data{$source}{'c'}}) >= 4;
	my $temp=_genR_frame($Data{$source}{'c'},$Data{$source}{'e'},$source,$oDir);
	_RFrameToPNG($temp,"Lum","Group",$oDir);
}

exit(0);


sub _genR_frame {
	my @control=@{$_[0]};
	my @experim=@{$_[1]};
	my $source = $_[2];
	my $out=$_[3];
	my @output;
	push @output, "Source,Value";
	foreach my $val (@control){
		push @output, "control,$val";
	}
	foreach my $val (@experim){
		push @output, "experimental,$val";
	}
	my $temp=$out."/$source.raw.csv";
	Tools->printToFile($temp,\@output);
	return $temp;
}

sub _RFrameToPNG {
	my $file =shift;
	my $xlab = shift;
	my $ylab = shift;
	my $out=$file;
	$out=~s/raw\.csv$//;
	my $title=$out;
	$title=~s/.+\///;
	$out.=".png";
	my $cmd="DF=as.data.frame(read.table(\"$file\",sep=\",\",header=TRUE))";
	$R->send($cmd);
	$cmd="png(file=\"$out\")";
	$R->send($cmd);
	$cmd="ggplot(data=DF,aes(x=Source,y=Value)) + geom_point(stat = \"identity\")  + theme(axis.text.x = element_text(angle=90,hjust=1)) + ggtitle(\"$title\") + xlab(\"$xlab\") + ylab(\"$ylab\") + ylim(0,364)";
	#$cmd="ggplot(data=DF,aes(x=Source,y=Value)) + geom_boxplot(stat = \"boxplot\", position = \"dodge\")  + theme(axis.text.x = element_text(angle=90,hjust=1)) + ggtitle(\"$title\") + xlab(\"$xlab\") + ylab(\"$ylab\") + ylim(0,384)";
	$R->send($cmd);
	my $res=$R->read();
	warn $res."\n" unless $res eq "";
	$cmd="dev.off()";
	$R->send($cmd);
	return 1;
}
