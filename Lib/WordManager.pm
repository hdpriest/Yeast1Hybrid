#!/usr/bin/perl
use warnings;
use strict;
use FindBin;
use threads;
use threads::shared;
use lib "$FindBin::Bin/../Lib";
use Configuration;
use Tools;
use Word;
use Thread::Queue;
our $q = Thread::Queue->new();  
package WordManager;

sub new {
	my $class=shift;
	my $self = {
		File		=> shift,
		Promoters	=> shift,
		Temp		=> shift,
		maxThreads	=> 16,
		words		=> [],
		objects	=> [],
		iterator	=> undef,
      };
      bless $self, $class;
	die "Must pass a file of words in!\n" unless defined $self->{File};
	die "Must pass in a promoter file (fasta)!\n" unless defined $self->{Promoters};
	die "Must pass in a temp directory!\n" unless defined $self->{Temp};
	$self=_loadFile($self);
      return $self;
}

sub getNextWord {
	my $self=shift;
	my $iterator=$self->{iterator};
	if(defined(${$self->{objects}}[$iterator])){
		my $obj=${$self->{objects}}[$iterator];
		$self->{iterator}++;
		return $obj;
	}else{
		return undef;
	}
}

sub _loadFile {
	my $self=shift;
	my @Words=@{Tools->LoadFile($self->{File})};
	my %Promoters=%{Tools->LoadFasta($self->{Promoters})};
	my $temp=$self->{Temp};
	foreach my $word (@Words){
		$q->enqueue($word);
	}
	for(my$i=0;$i<=$self->{maxThreads};$i++){
		warn "spawning thread $i\n";
		my $thr=threads->create(\&_findHits,\%Promoters,$temp);
	}
	while(threads->list()>0){
		my @thr=threads->list();
		$thr[0]->join();
	}
	my %words;
	for(my$i=0;$i<=$self->{maxThreads};$i++){
		my $file=$temp."/Temp.$i.txt";
		my @file=@{Tools->LoadFile($file)};
		foreach my $line (@file){
			my ($w,$ps)=split("\t",$line);
			my $obj=Word->new($w);
			my @hits=split(/\,/,$ps);
			foreach my $p (@hits){
				$obj->addPromoter($p);
			}
			$words{$w}=$obj;
		}
	}
	my @words;
	my @objects;
	foreach my $W (@Words){
		push @words, $W;
		push @objects, $words{$W};
	}
	$self->{words}=\@words;
	$self->{objects}=\@objects;
	$self->{iterator}=0;
	return $self;
}

sub _findHits {
	my $TID=threads->tid() -1 ;
	my %Promoters=%{$_[0]};
	my $tempDir=$_[1];
	my $output=$tempDir."/Temp.$TID.txt";
	my @output;
	while(my $w=$q->dequeue_nb()){
		my $rc=Tools->revcomp($w);
		my @hits;
		foreach my $key (keys %Promoters){
			if($Promoters{$key}=~m/$w/){
				push @hits, $key;
			}elsif($Promoters{$key}=~m/$rc/){
				push @hits, $key;
			}
		}
		push @output, $w."\t".join(",",@hits);
	}
	Tools->printToFile($output,\@output);
}

1;

