#!/bin/bash

# --------------------------------------------------
# Shell functions
trap "myExit" SIGINT SIGTERM
myExit () {
  rm -f $config_file
  rm -f $tmp_stdout
}

dexit () {
  echo $1
  exit 1
}

vprint () {
  [[ $verbose == 1 ]] && echo "$@"
}


# --------------------------------------------------
# Digest commandline options
timestamp=$(date '+%Y%m%d-%H%M%S')
rsync='rsync'
verbose=0

while getopts 'vhf:' tag; do
  case "$tag" in
    f) config_filename="$OPTARG" ;;
    h) cat<<-EOF
		Rsync backup wrapper with link-dest support
		
		$(basename $0) [-h] [-v] [-f <config file>]
		  -h Usage (this text)
		  -v verbose
		  -f config file
		
		CONFIG FILE
		The config file should be whitespace separated. Lines starting with #
		and empty lines are ignored. It should have the following format:
		
		   /path/to/src /path/to/dest -any -rsync -options -xyz 
		
		Any text after the 2nd field are passed straight to rsync.
		
		EXAMPLES
		I use the following to back up my root file system
		   / /mnt/backup -a -x
		
		I back up all my private git repos on a cloud server with this command:
		   gitadmin@cloudserver:/var/gitrepos /mnt/backup -a 
		
		My home directory has many files which don't need backing up, so I
		have an extra file with patterns to exclude from the backup:
		   /home/fimblo /mnt/backup -a --exclude-from=my-exclude.config
		
		Content of my-exclude.config
		   Dropbox
		   /home/fimblo/.cache
		   /home/fimblo/.config/google-chrome
		EOF
       exit 0
    ;;
    v) verbose=1;
  esac
done


# --------------------------------------------------
# Read config file
[[ -f $config_filename ]] || dexit "Abort: Can't find config file '$config_filename'"
config_file=$(mktemp)
cat $config_filename | grep -vE "^[ ]*\#" | grep . > $config_file


# --------------------------------------------------
# Step through config file and run each backup
while read -r line ; do
  src_in=$(echo $line | cut -f1  -d' ')
  dst_in=$(echo $line | cut -f2  -d' ')
  opt_in=$(echo $line | cut -f3- -d' ') # note the trailing dash to capture the rest

  # --------------------------------------------------
  # CREATE UNIQUE SOURCE IDENTIFIER

  # special case: if backing up root filesystem, the slash will later
  # be removed. So replace it now with the string 'root-filesystem'
  src_unique=$src_in
  [[ $src_in == '/' ]] && src_unique='/root-filesystem'

  # Prepend hostname if it is missing
  hn=$(hostname)
  ! $(echo $src_in | grep -q ':') && src_unique="${hn}:$src_unique"
  
  # Get unique source identifier
  unique=$(echo $src_unique | tr '/@:' '-' | perl -pe 's/^-|-$//g')

  
  # --------------------------------------------------
  # CREATE LINK IF POSSIBLE

  # hard link back to previous backup if there was one
  [[ -L $dst_in/$unique/current ]] && link_back='--link-dest ../current'


  # --------------------------------------------------
  # FIDDLE WITH DESTINATION DIRECTORY

  # define new backup location
  dst_real="$dst_in/$unique/$timestamp"


  # --------------------------------------------------
  # START MAKING CHANGES

  vprint "Real target: $dst_real"
  [[ $verbose == 1 ]] && mkdir -p $dst_real || mkdir -p $dst_real

  # the command we will run
  vprint "Command: $rsync $link_back $opt_in $src_in $dst_real"

  # run the command
  tmp_stdout=$(mktemp)
  $rsync $link_back $opt_in $src_in $dst_real | tee $tmp_stdout 2>&1 
  retval=$?


  # --------------------------------------------------
  # POST CHANGE FORMALITIES  

  # tell world if error, else create new symlink to this backup
  if [[ $retval != 0 ]] ; then
    echo $rsync exitted with code: $retval
    rm -rf $dst_real
  else
    if [[ $verbose != 0 ]] ; then
      rm -f $dst_in/$unique/current
      ln -s $dst_real $dst_real/../current
    fi
  fi

  # delete directory if it was a dry run
  if tail -n 2 $tmp_stdout | grep -q '(DRY RUN)' ; then
    rm -rf "$dst_in/$unique/$timestamp"
    [[ $(find "$dst_in/$unique" | wc -l) == 1 ]] && rm -rf "$dst_in/$unique"
  fi
done <$config_file
