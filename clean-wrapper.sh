#!/bin/bash

ME=$(basename $0)
MYDIR=$(dirname $0)

LOGDIR=/var/log
LOGFILE=$LOGDIR/backup-sh.log

export DBK=/mnt/raid/backup
PERIOD=$1


exec >>   >(tee -a $LOGFILE)   2>&1
date +"%Y-%m-%d %H:%M:%S $0 begin" >> $LOGFILE

[[ -z $PERIOD ]] && echo "Error: missing PERIOD parameter."


$MYDIR/clean.sh $PERIOD
status=$?
[[ $status -ne 0 ]] && echo "Error: Exited with status '$status'."

date +"%Y-%m-%d %H:%M:%S $0 end" >> $LOGFILE
exit $status


