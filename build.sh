#!/bin/sh

MAKE=make
if [ -n 'colormake' ]; then
	MAKE=colormake
else

sudo umount /mnt/sda1
sudo umount /mnt/sda2
sudo modprobe -r ext4
${MAKE} M=fs/ext4 C=2 CF=D__CHECK_ENDIAN__
${MAKE} M=fs/ext4 -j8
sudo cp fs/ext4/ext4.ko /lib/modules/`uname -r`/kernel/fs/ext4/
sudo modprobe ext4
