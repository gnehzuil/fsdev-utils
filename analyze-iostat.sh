#!/bin/sh

logfile=$1
dev=$2

# read sectors
grep "$dev" "$logfile" | awk 'BEGIN{cnt=0}{cnt+=$6}END{printf "read sectors: \t%f\n", cnt/NR}'

# write sectors
grep "$dev" "$logfile" | awk 'BEGIN{cnt=0}{cnt+=$7}END{printf "write sectors: \t%f\n", cnt/NR}'

# io queue size
grep "$dev" "$logfile" | awk 'BEGIN{cnt=0}{cnt+=$8}END{printf "queue size: \t%f\n", cnt/NR}'

# request size
grep "$dev" "$logfile" | awk 'BEGIN{cnt=0}{cnt+=$9}END{printf "request size: \t%f\n", cnt/NR}'

# await
grep "$dev" "$logfile" | awk 'BEGIN{cnt=0}{cnt+=$10}END{printf "await: \t\t%f\n", cnt/NR}'
