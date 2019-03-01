#!/bin/bash
## Who am I?
_script="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
#echo $_script

## Directory
_basedir="$(dirname $_script)" # Assuming that chk/ is within local /src directory
#_basedir="${_chkdir%/*}"
echo "Package location: $_basedir"

## Log files
_logdir=$(dirname $_basedir)""/.logs/
_logfile=$(date +"%Y%m%dT%H%M%S")"".log

## Version 
ver=$(cat $_basedir/ver)
echo "Package version: $ver"

echo "Testing internet connection..."
ping -c1 google.com

if [ $? -eq 0 ]; then
	echo "Success!"
	## Server version
	usr=alt5225
	host=hammer.rcc.psu.edu
	_srcdir=/gpfs/group/sleic/rog1/ssvp/src/
	echo "Source directory: $usr@$host:$_srcdir"
	srcver=$(ssh $usr@$host 'cat '$_srcdir'/ver')
	echo "Source version: $srcver"

	## Version test (float, with bc)
	version_test=$(echo "$ver < $srcver" | bc)
	if [ $version_test -eq 1 ]; then
		echo "Version ($ver) not up to date."	
		echo "Initiating update: rsync from $_srcdir/ to $_basedir.  Please maintain internet connection."
		rsync -ruv --delete --exclude-from '.local/chk/exlist.txt' --log-file=$_logdir$_logfile $usr@$host:$_srcdir/* $_basedir
	else
		echo "Version ($ver) up to date."
	fi
else
	echo "Failed to connect."
fi
