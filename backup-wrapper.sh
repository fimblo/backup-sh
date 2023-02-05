#!/bin/bash

ME=$(basename $0)
MYDIR=$(dirname $0)

LOGDIR=/var/log
LOGFILE=$LOGDIR/backup-sh.log

exec >>   >(tee -a $LOGFILE)   2>&1
date +"%Y-%m-%d %H:%M:%S $0 begin" >> $LOGFILE

$MYDIR/bk.sh -f $MYDIR/cfg/rsync-config
status=$?
[[ $status -ne 0 ]] && echo "Exited with status '$status'."

date +"%Y-%m-%d %H:%M:%S $0 end" >> $LOGFILE
exit $status
