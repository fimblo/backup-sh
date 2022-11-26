#!/bin/bash
#
# Required
# DBK    The directory where the backups are stored by bk.sh
#



if [[ -z "$DBK" ]] ; then
  echo "envvar DBK not defined"
  exit 1;
fi


usage() {
  echo usage vettu
}

# if arg=year, clone today's backup to year/

clone () {
  period=$1

  backup_sources=$(find $DBK -maxdepth 1 -mindepth 1 -type d)

  for sid in $backup_sources ; do
    bk_datetime=$(basename $(readlink -f $sid/current)) # YYYYMMDD-HHMMSS
    source=$sid/$bk_datetime                            # $DBK/peanut--home/20221122-205559
    target=$sid/$period                                 # $DBK/peanut--home/$period
    sudo mkdir -p $target
    [[ -d $target/$bk_datetime ]] || \
      sudo cp -lax $source $target/$bk_datetime
  done
}

clean () {
  period=$1
  delete_after=$2

  [[ $period == "daily" ]] && unset period

  find $DBK/$period \
       -mindepth 2 \
       -maxdepth 2 \
       -name '20??????-??????' \
       -ctime +$delete_after # -exec rm -rf {} \;
}


# Grab and execute according to commandline arguments
arg=$1

if [[ -z "$arg" ]] ; then
  usage
  exit 0
fi

case "$arg" in
  year)
    clone yearly
    ;;
  month)
    clone monthly
    clean monthly 12
    ;;
  week)
    clone weekly
    clean weekly 5
    ;;
  day)
    clean daily 14;;
  *) usage
     exit 0;;
esac
