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
my $EXID=$Config->get('OPTIONS',"ID");
my $oDir=$Config->get('PATHS','Output');
my $iDir=$Config->get('PATHS','DataDir');
my $wordFile=$Config->get('PATHS','Words');
my $promoter=$Config->get('PATHS','Promoters');
my $tempDir =$Config->get('PATHS','TempDir');
my $barcodes=$Config->get('PATHS','Barcodes');
my $cutRatio=$Config->get('OPTIONS','OD_cutRatio');
$cutRatio = .1 if $cutRatio == -1;
my @Barcodes = @{Tools->LoadFile($iDir."/".$barcodes)};
my $Run = y1hRun->new();
$Run->parseExperiment($Config,\@Barcodes);

my $R=Statistics::R->new();
$R->startR();
$R->send("library(ggplot2)");

my %s;

my @Control=@{$Run->getPlatesBySet("control")};
my @Experim=@{$Run->getPlatesBySet("experimental")};
print "\n\n";
my %cod = %{_getODhistogram(\@Control)};
my %eod = %{_getODhistogram(\@Experim)};

_pickCutoff(\%cod,$cutRatio,"control");
_pickCutoff(\%eod,$cutRatio,"experiment");

exit(0);

sub _pickCutoff {
	my %data=%{$_[0]};
	my $rat=$_[1];
	my $phrase=$_[2];
	my @counts;
	my $index=0;
	my $max=0;
	my $N = 0;
	foreach my $od (sort {$a <=> $b} keys %data){
		push @counts, $data{$od};
		$N+=$data{$od};
		if($data{$od} > $max){
			$index = $od;
			$max=$data{$od};
		}
	}
	my $CUT = $max*$rat;
	print "Found maximum number of ODs ($max) at od $index\nCutoff is $CUT\n";
	my $lcut = undef;
	my $ucut = undef;
	my $numcut=0;
	for(my $b=$index;$b>=0;$b-=0.01){
		my $B = sprintf("%.2f",$b);
		next unless defined $data{$B};
		if($data{$B}<$CUT){
			if(defined($lcut)){
				$numcut+=$data{$B};
			}else{
				$lcut = $B;
			}
		}
	}
	for(my $t=$index;$t<=1.5;$t+=0.01){
		my $T = sprintf("%.2f",$t);
		next unless defined $data{$T};
		if($data{$T}<$CUT){
			if(defined($ucut)){
				$numcut+=$data{$T};
			}else{
				$ucut = $T;
			}
		}
	}
	my $perc = ($numcut/$N)*100;
	$perc=sprintf("%.2f",$perc);
	print "for $phrase\n";
	print "Found lower cut level @ $lcut\n";
	print "Found upper cut level @ $ucut\n";
	print "Cut out $numcut of $N wells ($perc\%)\n\n";

}



sub _getODhistogram {
	my @Plates = @{$_[0]};
	my %od;
	foreach my $Plate (@Plates){
		my $ID = $Plate->getID();
		my @SL = @{$Plate->getSourceListInOrder()};
		my %Sources;
		map {$Sources{$_}=1} @SL;
		foreach my $s (keys %Sources){
			my @OD = @{$Plate->getODBySource($s)};
			my @Lum= @{$Plate->getLumBySource($s)};
			for(my$i=0;$i<=$#OD;$i++){
				my $od=sprintf("%.2f",$OD[$i]);
				if(defined($od{$od})){
					$od{$od}+=1;
				}else{
					$od{$od}=1;
				}
			}
		}
	}
	return \%od;
}

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
#	warn "$cmd\n";
	$R->send($cmd);
	$cmd="png(file=\"$out\",height=1200,width=1200,units=\"px\")";
#	warn "$cmd\n";
	$R->send($cmd);
#	png(file="test.png",width=1200,height=1200,units="px")
#	> ggplot(data=DF,aes(x=OD,y=Lum,group=OD)) + geom_boxplot()
	$cmd="ggplot(data=DF,aes(x=$group,y=$plot)) + geom_bar(stat=\"identity\") + theme(axis.text.x = element_text(angle=90,hjust=1)) + ggtitle(\"$title\")+ xlim(0,1.5) + ylim(0,50)";
#	warn "$cmd\n";
	$R->send($cmd);
	$cmd="dev.off()";
	$R->send($cmd);
	return 1;
}

sub _genR_frame_PerSource {
	my %data = %{$_[0]};
	my $id = $_[1];
	my $type = $_[2];
	my @output;
	push @output, "OD,value";
	foreach my $od (sort {$a <=> $b} keys %data){
		my $line = $od.",".$data{$od};
		push @output, $line;
	}
	my $temp=$oDir."/".$id.".$type.ODhistogram.csv";
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
#		my $path=$Config->get('PATHS','DataDir')."/".$file;
		my $path=$file;
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




