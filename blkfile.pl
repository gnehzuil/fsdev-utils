#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

# get argument

my $device = '';
my $mnt = '';
my $workdir = '';
my $prefix = '';
my $interval = 0;
my $export = 0;
my $blktrace = 0;
my $analyze = 0;
GetOptions ("analyze"		=> \$analyze,	# analyze
	    "blktrace"		=> \$blktrace,	# grab io requests using blktrace
	    "device=s"		=> \$device,	# device
	    "export"		=> \$export,	# dump file's layout
	    "mount=s"		=> \$mnt,	# analze dir
	    "prefix=s"		=> \$prefix,	# prefix
	    "workdir=s"		=> \$workdir,	# work dir
	    "interval=i"	=> \$interval,	# sleep interval
);

if ($device eq '') {
	print "Please input device argument (-d)\n";
	exit 1;
}

if ($mnt eq '') {
	print "Please input mount dir argument (-m)\n";
	exit 1;
}

if ($workdir eq '') {
	print "Please input work dir argument (-w)\n";
	exit 1;
}

if ($prefix eq '') {
	print "Please input prefix argument (-p)\n";
	exit 1;
}

print "== argument ==\n";
print "device: $device\n";
print "dir: $mnt\n";
print "prefix $prefix\n";
print "workdir: $workdir\n";
print "interval: $interval\n";

if ($analyze eq 0 and $blktrace eq 0 and $export eq 0) {
	print "You need to indicate operation:\n";
	print "\t1. export files (-e)\n";
	print "\t2. catch io requests using blktrace (-b)\n";
	print "\t3. analyze the result (-a)\n";
	exit 1;
}

my $base_dir = "$workdir/blkfile";
my $files_dir = "$base_dir/files";
my $blktrace_dir = "$base_dir/blktrace";
my $result_dir = "$base_dir/result";

mkdir $base_dir if ! -e $base_dir;

sub export_file {
	mkdir $files_dir if ! -e $files_dir;
	open(my $files, ">", "$files_dir/files") or die "can't open files: $!";
	opendir(DIR, $mnt) or die "can't open dir $mnt: $!";

	while ((my $filename = readdir(DIR))) {
		next if ($filename eq '.' or $filename eq '..');
		next if -d "$mnt/$filename";
		my $debug_res = `debugfs -R 'ex $prefix/$filename' $device`;
		my @debug_res_arr = split('\n', $debug_res);
		my $res = '';
		for (@debug_res_arr) {
			next if (/Level*/);
			my @extents = split(' ', $_);
			$res = join(':', "$res", "$extents[7]-$extents[9]");
		}
		# $filename:$ex_start1-$ex_end1:$ex_start2-$ex_end2:...
		$res = "$filename$res\n";
		print $files $res;
	}

	closedir(DIR);
	close $files or die "$files: $!";
}

sub mount_debugfs() {
	my $mount = `mount`;
	my @mount_arr = split('\n', $mount);
	my $has_mount = 0;
	foreach (@mount_arr) {
		if (/debugfs/) {
			$has_mount = 1;
		}
	}

	if ($has_mount eq 0) {
		`sudo mount -t debugfs none /sys/kernel/debug`;
	}
}

sub parse_blks() {
	open(my $in, "<", "$blktrace_dir/uniq.log") or die "can't open files: $!";
	open(my $out, ">", "$blktrace_dir/blocks") or die "can't open files: $!";

	my $sector = 0;
	my $sector_par = 0;
	while (<$in>) {
		chomp $_;
		my @data = split(' ', $_);
		if ($data[5] =~ /A/ and $data[6] =~ /R/) {
			$sector = $data[7];
			$sector_par = $data[12] / 8;
		} elsif ($data[5] =~ /D/ and $data[6] =~ /R/) {
			if ($sector eq $data[7]) {
				print $out "$sector_par\n";
				$sector = 0;
				$sector_par = 0;
			} else {
				$sector = 0;
				$sector_par = 0;
			}
		}
	}
	
	close $in or die "$in: $!";
	close $out or die "$in: $!";
}

sub catch_blktrace {
	&mount_debugfs();

	mkdir $blktrace_dir if ! -e $blktrace_dir;

	my $pid = fork();
	if (not defined $pid) {
		print "can't fork\n";
		exit 1;
	} elsif ($pid eq 0) {
		exec "blktrace -d /dev/sdb1 -o blktrace";
	} else {
		print "waiting for a minute\n";
		sleep 3;
		print "try to kill blktrace command\n";
		kill 2, $pid;
		print "killed\n";
		
		sleep 1;
		`blkparse -i blktrace.* -o blktrace.log`;
		`mv blktrace.* $blktrace_dir`;
		`cat $blktrace_dir/blktrace.log | sed -n -e '/^  8/p' | uniq > $blktrace_dir/uniq.log`;
		&parse_blks();
	}
}

sub do_analyze {
	mkdir $result_dir if ! -e $result_dir;

	open(my $blocks, "<", "$blktrace_dir/blocks") or die "can't open files: $!";
	open(my $files, "<", "$files_dir/files") or die "can't open files: $!";
	open(my $hit, ">", "$result_dir/hit.log") or die "can't open files: $!";
	open(my $miss, ">", "$result_dir/miss.log") or die "can't open files: $!";

	my @export_files = <$files>;

	while (<$blocks>) {
		chomp $_;
		my $block = $_;
		my $h = 0;
		my $fileinfo = '';
		foreach (@export_files) {
			chomp $_;
			$fileinfo = $_;
			my @export_file = split(':', $_);
			my $filename = $export_file[0];
			for (my $i = 0; $i < @export_file; $i++) {
				next if ($i eq 0);

				my @extent = split('-', "${export_file[$i]}");
				my $ex_start = $extent[0];
				my $ex_end = $extent[1];
				if ($ex_start <= $block and $block <= $ex_end) {
					$h = 1;
				}
			}
		}

		if ($h eq 1) {
			print $hit "$fileinfo:$block\n";
			$h = 0;
			$fileinfo = '';
		} else {
			print $miss "$fileinfo:$block\n";
			$h = 0;
			$fileinfo = '';
		}
	}

	close $blocks or die "$blocks: $!";
	close $files or die "$files: $!";
	close $hit or die "$hit: $!";
	close $miss or die "$miss: $!";
}

if ($export eq 1) {
	print "--- start to export files ---\n";
	&export_file();
}

if ($blktrace eq 1) {
	print "--- start to catch the io requests ---\n";
	&catch_blktrace();
}

if ($analyze eq 1) {
	print "--- start to analyze the result ---\n";
	&do_analyze();
}
