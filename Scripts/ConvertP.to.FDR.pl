#!/usr/bin/perl
use warnings;
use strict;
use Statistics::Multtest qw(:all);
use hdpTools;

my $file=$ARGV[0];
die "usage: perl $0 <file of p-values, p-values in col 4>\n\n" unless $#ARGV==0;

my @P;
my @output;
warn "Loading data...\n";
open(FILE,"<",$file) || die "cannot open $file!\n$!\nexiting...\n";
until(eof(FILE)){
	my $line=<FILE>;
	chomp $line;
	my @line=split(/\t/,$line);
	push @P, $line[1];
	push @output, $line;
}
close FILE;
warn "Done.\n";
warn "Getting FDR....\n";
my @FDRs=@{GetFDR_p(\@P)};
warn "Done.\n";
warn "Printing...\n";
for(my$i=0;$i<=$#FDRs;$i++){
	print $output[$i]."\t".$FDRs[$i]."\n";
}
warn "Done\n";

sub GetFDR_p {
	my $method=$_[1];
	my $res=bonferroni($_[0]);
	return $res;
}
