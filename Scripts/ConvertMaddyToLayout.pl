#!/usr/bin/perl
use warnings;
use strict;

use hdpTools;

my $in=$ARGV[0];

die "usage: perl $0 <file: <LetterNumber<tab>Rep-well-rack>\n\n" unless defined $ARGV[0];

my @file=@{hdpTools->LoadFile($in)};
my @rows=("A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P");
my %Layout;
foreach my $line (@file){
	next if $line=~m/^Map/;
	my ($well,$source)=split(/\t/,$line);
#	D1,1-B1-3,,,,,,,,,,,,,,,,,,,,,,,,
#	E1,1-C1-1,,,,,,,,,,,,,,,,,,,,,,,,
#	F1,1-C1-3,,,,,,,,,,,,,,,,,,,,,,,,
	my ($rack,$swell,$rep)=split(/\-/,$source);
	$well=~m/(\w)(\d+)/;
	my $letter=$1;
	my $number=$2;
	my $stanza="R".$rack."-$swell";
	if(defined($Layout{$letter})){
		$Layout{$letter}{$number}=$stanza;
	}else{
		$Layout{$letter}={};
		$Layout{$letter}{$number}=$stanza;
	}
}
my @output;
my $head="Layout";
foreach my $row (@rows){
	my $out=$row;
	for(my $i=1;$i<=24;$i++){
		if($row eq $rows[0]){
			$head.=",".$i;
		}
		$out.=",".$Layout{$row}{$i};
	}
	push @output, $out;
}
unshift @output, $head;

map{print $_."\n"} @output;
