#!/bin/bash
# script to download kernel updates for CentOS, run this on an AMD built to the same spec as those you wish to update.
# running on a system built to different specs will possible result in a package that is incomplete and won't deploy on the AMDs
# will use YUM to check for updates and download them, package them up for deployment.
#
# first parameter output file name. provide a full path.

### config parameters

# key pakcages to update, dependencies will be automatically added.
PKGLIST="kernel microcode_ctl linux-firmware"


### code follows
DEBUG=1

### function code

function debugecho {
	dbglevel=${2:-1}
	if [ $DEBUG -ge $dbglevel ]; then techo "*** DEBUG[$dbglevel]: $1"; fi
}

function techo {
	echo -e "[`date -u`][$AMDNAME]: $1" 
}


### main code
PKGFILE=${1:-${PWD}/centosupdate.tar.bz2}

#output file sanity check
if [ -f $PKGFILE ]; then
	echo "Output file $PKGFILE exists, aborting."
	exit 1
fi


TMPDIR=$(mktemp -d)
echo "Downloading update packages..."
OUTPUT=$(sudo yum update --setopt=deltarpm=0 --downloadonly --downloaddir="${TMPDIR}/centosupdate/" ${PKGLIST} 2>&1)
RC=$?
debugecho "OUTPUT:$OUTPUT"
if [ $RC -ne 0 ]; then
	echo -e "Package download failed, yum output:\n${OUTPUT}"
	exit 1
fi
echo "Download complete"

#archive the download packages
echo "Archiving update packages..."
OUTPUT=(
cd $TMPDIR &&
tar -cjf "${PKGFILE}" centosupdate/
)
RC=$?
debugecho "OUTPUT:$OUTPUT"
if [ $RC -ne 0 ]; then
	echo -e "Couldn't archive packages in ${TMPDIR}. Output:\n${OUTPUT}\nAborting"
	exit 1
fi
echo "Archive complete"


#clean up temp dir
rm -rf "${TMPDIR}"
RC=$?
if [ $RC -ne 0 ]; then	
	echo "Failed to remove temp directory: ${TMPDIR}"
	exit 1
fi

#done
echo "Update package saved as: ${PKGFILE}"
exit 0


