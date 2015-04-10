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
my @Barcodes = @{Tools->LoadFile($iDir."/".$barcodes)};
my $Run = y1hRun->new();
$Run->parseExperiment($Config,\@Barcodes);

warn "Starting R...\n";
my $R=Statistics::R->new();
$R->startR();
$R->send("library(ggplot2)");
warn "Done.\n";
my @Plates=@{$Run->getPlatesBySet("control")};
map {$_->normalizeDataByOD(@ctr_od_range)} @Plates;
for(my $i=0;$i<=$#Plates;$i++){
	for(my$j=$i;$j<=$#Plates;$j++){
		next if $j==$i;
		my $quadFile   = _genR_frame_LumByRank($Plates[$i],$Plates[$j],"Rank");
		next 	unless defined $quadFile;
		_RFrameToPNG($quadFile,$Plates[$i]->getID(),$Plates[$j]->getID());	
	}
}
@Plates=@{$Run->getPlatesBySet("experimental")};
map {$_->normalizeDataByOD(@exp_od_range)} @Plates;
for(my $i=0;$i<=$#Plates;$i++){
	for(my$j=$i;$j<=$#Plates;$j++){
		next if $j==$i;
		my $quadFile   = _genR_frame_LumByRank($Plates[$i],$Plates[$j],"Rank");
		next 	unless defined $quadFile;
		_RFrameToPNG($quadFile,$Plates[$i]->getID(),$Plates[$j]->getID());	
	}
}

exit(0);

sub _precheck {
	my $pi = shift;
	my $pj = shift;
	my %sources;
	map {$sources{$_}=1} @{$pi->getSourceList()};
	map {$sources{$_}=1} @{$pj->getSourceList()};
	my $hit=undef;
	foreach my $s (keys %sources){
		next unless (($pi->checkForSource($s)) && ($pj->checkForSource($s)));
		$hit=1;
	}
	return $hit;
}

sub _genR_frame_LumByRank {
	my $Plate_i=shift;	
	my $Plate_j=shift;	
	return undef unless _precheck($Plate_i,$Plate_j);
	my $Value=shift;
	my @output;
	push @output, "Source,X,Y";
	my $id_i = $Plate_i->getID();
	my $id_j = $Plate_j->getID();
	warn "$id_i vs $id_j\n";
	$id_i=~s/\.txt//;
	$id_j=~s/\.txt//;
	my %Lum_i = %{$Plate_i->getLumRanks()};
	my %Lum_j = %{$Plate_j->getLumRanks()};
	my %S;
	map {$S{$_}=1} keys %Lum_i;
	map {$S{$_}=1} keys %Lum_j;
	foreach my $source (keys %S){
		next unless defined $Lum_i{$source};
		next unless defined $Lum_j{$source};
		my $line=$source.",".$Lum_i{$source}.",".$Lum_j{$source};
		push @output, $line;
	}
	my $temp=$oDir."/".$id_i.".vs.".$id_j.".byRank.csv";
	Tools->printToFile($temp,\@output);
	return $temp;
}

sub _getRanksByPlate {
	my $Plate=shift;
	my @sources = @{$Plate->getSourceList()};
	my %R;
	foreach my $s (@sources){
		my @L = @{$Plate->getLumBySource($s)};
		for(my$x=0;$x<=$#L;$x++){
			my $L=$L[$x];
#		foreach my $L(@L){
			if(defined($R{$L})){
				push @{$R{$L}}, $s;
				#warn "pushing $s at $L, size now ".scalar(@{$R{$L}})."\n";
			}else{
				$R{$L}=[];
				push @{$R{$L}}, $s;
			}
		}
	}
	return \%R;
}

sub _RFrameToPNG {
	my $file =shift;
	my $xlab = shift;
	my $ylab = shift;
	my $out=$file;
	$out=~s/csv$//;
	my $title=$out;
	$title=~s/.+\///;
#	$title=~s/ByColumn//;
#	$title=~s/ByRow//;
	$out.=".png";
	my $cmd="DF=as.data.frame(read.table(\"$file\",sep=\",\",header=TRUE))";
	$R->send($cmd);
	$cmd="png(file=\"$out\")";
	$R->send($cmd);
	$cmd="ggplot(data=DF,aes(x=X,y=Y,group=Source)) + geom_point() + theme(axis.text.x = element_text(angle=90,hjust=1)) + ggtitle(\"$title\") + xlab(\"$xlab\") + ylab(\"$ylab\")";
	$R->send($cmd);
	$cmd="dev.off()";
	$R->send($cmd);
	return 1;
}

sub _genR_frame_ValuesByRow {
	my $Plate=shift;	
	my $Value=shift;
	my $id=$Plate->getID();
	$id=~s/\.txt//;
	my @output;
	my @rows=("A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P");
	push @output, "Row,$Value";
	for(my$r=0;$r<=$#rows;$r++){
		my $row=$rows[$r];
		my @data=@{$Plate->getDataByRow($row,$Value)};
		for(my $n=0;$n<=$#data;$n++){
			my $line="$row,$data[$n]";
			push @output, $line;
		}
	}
	my $temp=$oDir."/".$id.".$Value.ByRow.csv";
	Tools->printToFile($temp,\@output);
	return $temp;
}

sub _genR_frame_ValuesByColumn {
	my $Plate=shift;	
	my $Value=shift;
	my $id=$Plate->getID();
	$id=~s/\.txt//;
	my @output;
	push @output, "Column,$Value";
	for(my$i=1;$i<=24;$i++){
		my @data=@{$Plate->getDataByColumn($i,$Value)};
		for(my $n=0;$n<=$#data;$n++){
			my $line="$i,$data[$n]";
			push @output, $line;
		}
	}
	my $temp=$oDir."/".$id.".$Value.ByColumn.csv";
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




