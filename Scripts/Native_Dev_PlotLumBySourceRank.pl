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

my @Barcodes = @{Tools->LoadFile($iDir."/".$barcodes)};
my $Run = y1hRun->new();
$Run->parseExperiment($Config,\@Barcodes);

$Run->normalizePlatesBySet("control",@ctr_od_range);
#$Run->normalizePlatesBySet("experimental",@exp_od_range);
my @Experim;
my @Control=@{$Run->getPlatesBySet("control")};
my @Plates=@Control;
my @Sources=@{$Run->getAllSources()};
my %Data;
for(my $i=0;$i<=$#Control;$i++){
	foreach my $s (@Sources){
		my @Lum = @{$Control[$i]->getLumBySource($s)};
		foreach my $lum (@Lum){
			if(defined($Data{$s})){
				push @{$Data{$s}{'c'}}, $lum;
			}else{
				$Data{$s}={};
				$Data{$s}{'c'}=[];
				$Data{$s}{'e'}=[];
				push @{$Data{$s}{'c'}}, $lum;
			}
		}
	}
}

my $temp=_genR_frame(\%Data,$oDir);
_RFrameToPNG($temp,"Lum","Group",$oDir);

exit(0);


sub _genR_frame {
	my %Data=%{$_[0]};
	my $out=$_[1];
	my @output;
	push @output, "Source,Value";
	foreach my $source (keys %Data){
		warn "Working on $source\n";
		my @control=@{$Data{$source}{'c'}};
		foreach my $val (@control){
			push @output, "$source,$val";
		}
	}
	my $temp=$out."/temp.raw.csv";
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
	$out.="png";
	my $cmd="DF=as.data.frame(read.table(\"$file\",sep=\",\",header=TRUE))";
	$R->send($cmd);
	$cmd="png(file=\"$out\")";
	$R->send($cmd);
#	$cmd="ggplot(data=DF,aes(x=Source,y=Value)) + geom_point(stat = \"identity\")  + theme(axis.text.x = element_text(angle=90,hjust=1)) + ggtitle(\"$title\") + xlab(\"$xlab\") + ylab(\"$ylab\") + ylim(0,364)";
	$cmd="ggplot(data=DF,aes(x=Source,y=Value)) + geom_boxplot(stat = \"boxplot\", position = \"dodge\")  + theme(axis.text.x = element_text(angle=90,hjust=1)) + ggtitle(\"$title\") + xlab(\"$xlab\") + ylab(\"$ylab\")";
	$R->send($cmd);
	my $res=$R->read();
	warn $res."\n" unless $res eq "";
	$cmd="dev.off()";
	$R->send($cmd);
	return 1;
}
