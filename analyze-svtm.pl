#!/usr/bin/perl

use warnings;
use strict;

open(my $in, "<", $ARGV[0]) or die "can't open file $ARGV[0]: $!";

my $sum = 0;
my $sector = 0;
my $start = 0;
my $end = 0;
my $cnt = 0;

while (<$in>) {
	chomp $_;
	my @line = split(' ', $_);
	if ($line[5] eq 'D' and $line[6] eq 'R') {
		$sector = $line[7];
		$start = $line[3];
	} elsif ($line[5] eq 'C' and $line[6] eq 'R' and $line[7] eq $sector) {
		$end = $line[3];
		$sum += ($end - $start);
		$start = 0;
		$end = 0;
		$sector = 0;
		$cnt++;
	}
}

close $in;

printf "average svctm: %f\n", $sum/$cnt;
