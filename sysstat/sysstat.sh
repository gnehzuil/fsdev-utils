#!/bin/bash

# set global variables
cwd=`pwd`
prog=$cwd/src
vmtouch=$prog/vmtouch
vmtouch_files=
logdir=$cwd/syslog-`date +"%y%m%d-%H%M"`
interval=5

trap "_cleanup; exit\$status" 0 1 2 3 15

_cleanup()
{
	echo "sysstat.sh exit"
}

usage()
{
	echo "sysstat.sh [-d logdir -h -i interval]"
}

# indicate log dir by user
while getopts "d:f:hi:" arg
do
	case $arg in
	d)
		logdir=$OPTARG
		;;
	f)
		vmtouch_files=$OPTARG
		;;
	h)
		usage
		exit 1
		;;
	i)
		interval=$OPTARG
		;;
	esac
done

# mkdir log dir
if [ -d $logdir ]
then
	echo "'$logdir' exists.  exit!"
	exit 1
else
	echo "mkdir $logdir"
	mkdir $logdir
fi

# build vmtouch
if [ ! -x $vmtouch ]
then
	gcc -o $vmtouch $prog/vmtouch.c
fi

# if $vmtouch_files isn't indicated by user, we don't
# count vmtouch data.
if [ -n $vmtouch_files ]
then
	vmtouch=
fi

while true
do
	curdir=$logdir/`date +"%H%M%S"`
	mkdir $curdir

	cat /proc/meminfo >$curdir/meminfo &
	mpstat >$curdir/mpstat &
	vmstat 1 2 >$curdir/vmstat &
	iostat -x 1 2 >$curdir/iostat &
	if [ ! -n $vmtouch ]; then
		$vmtouch -v $vmtouch_files >$curdir/vmtouch &
	fi

	sleep $interval
done
