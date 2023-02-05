#!/bin/bash
#
# Required
# DBK    Absolute path to directory where the backups are stored
#


if [[ 0 != $(id -u) ]] ; then
  echo "Must run as root."
  exit 1;
fi

if [[ -z "$DBK" ]] ; then
  echo "envvar DBK not defined"
  exit 1;
fi


usage() {
  echo usage vettu
}


# Function to hard-link copy most recent backup to that source's
# {period}/ directory, where {period} can be one of the following:
# weekly, monthly or yearly
#
# An assumption in the code is that the most recent backup directory
# has been symlinked to a file named 'current'.
duplicate () {
  period=$1

  backup_sources=$(find $DBK -maxdepth 1 -mindepth 1 -type d)

  for sid in $backup_sources ; do
    bk_datetime=$(basename $(readlink -f $sid/current)) # YYYYMMDD-HHMMSS
    source=$sid/$bk_datetime                            # $DBK/hostname--home/20221122-205559
    target=$sid/$period                                 # $DBK/hostname--home/$period
    mkdir -p $target
    if [[ -d $target/$bk_datetime ]] ; then
      echo "Target '$target/$bk_datetime' already exists. Will not duplicate."
    else
      cp -lax $source $target/$bk_datetime
    fi
  done
}

clean () {
  period=$1
  keep=$2

  function _delete_old_stuff {
    clean_here=$1 # where to do the cleaning
    keep=$2       # keep this many most recent items

    # This assumes that all the directories in $clean_here has dates
    # as filenames, and they follow the format 20YYMMMDD-HHMM
    for backup_dir in $(\ls -1 $clean_here | grep ^20 | sort | head -n -$keep) ; do
      rm -rf $clean_here/$backup_dir
    done
  }

  for bkroot in $(find $DBK -maxdepth 1 -mindepth 1 -type d) ; do
    [[ $period == 'daily' ]] && period=''
    _delete_old_stuff $bkroot/$period $keep
  done

  
}


# Grab and execute according to commandline arguments
scope=$1     # day, week, month or year

if [[ -z "$scope" ]] ; then
  usage
  exit 0
fi

case "$scope" in
  year)
    duplicate yearly
    ;;
  month)
    duplicate monthly
    clean monthly 12 # delete all but the last 12 backups
    ;;
  week)
    duplicate weekly
    clean weekly 5 # delete all but the last 5 backups
    ;;
  day)
    clean daily 14 # delete all but the last 14 backups
    ;;
  *) usage
     exit 0;;
esac
