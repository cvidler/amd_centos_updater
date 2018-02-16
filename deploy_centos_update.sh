#!/bin/bash
# Package Deployment script for APMRS CentOS 7.3 AMDs
# Chris Vidler Dynatrace DC RUM SME 19 Jan 2018
#
# Uploads, extracts, and installs kernel updates to CentOS AMDs.
# Reboots the AMD after successful updating.
#
# Usage
# deploy_centos_update.sh amdaddress|amdaddresslistfile
# Accepts either a single AMD ip/dns address to deploy too, or 
# a file containing AMD addresses (IP or DNS) one per line.


#default options

# user to connect to AMDs with
SSHUSER="root"

# if you have ssh key auth set up it'll save you typing the passwrod three times per AMD! provide the key file path here
# ensure it's not an encrypted key or you'll still have to enter a password many many times
SSHKEY=""

# ping timeout (s), increase this if distant/slow AMDs fail the test.
PINGTO=2

# file to deploy.
DEPLOYPKG="dod_kernel_update.tar.bz2"

# RPM update flag
# "U" update packages, will report a fail if packages already up to date.
# "F" freshen packages, will report success if packagaes already up to date, will result in needless reboot of AMD 
UPDATEFLG="F"

# Additional ssh arguments. This optional argument suppresses manual host authenticity prompt. This occurs when an AMD has not been connected to previously.
# This can be commented out to suppress this potentially insecure behaviour.
OPTSSHARGS="-o ""StrictHostKeyChecking=no"""



# --- code below ---

# deps sanity check
SSH=`which ssh`
if [ $? -ne 0 ]; then echo "Can't find SSH. Aborting"; exit 254; fi
SCP=`which scp`
if [ $? -ne 0 ]; then echo "Can't find SCP. Aborting"; exit 254; fi


# file sanity check
if [ ! -r $DEPLOYPKG ]; then
	echo "Can't read file $DEPLOYPKG. Aborting"
	exit 1
fi

# if key specified add command line info
if [ ! "$SSHKEY" == "" ] && [ -r $SSHKEY ]; then
	SSHKEY=" -i $SSHKEY "
else
	SSHKEY=""
fi

# if user is not root, add sudo to commands
if [ ! "$SSHUSER" == "root" ]; then
	SUDO="sudo "
else
	SUDO=""
fi

# AMD address sanity check
AMD=${1:-none}
if [ $AMD == none ]; then
	echo "No AMD address specified. Aborting"
	exit 2
fi
if [ -r $AMD ]; then
	# it's a list file
	echo "Reading AMD list from file $AMD"
	AMDLIST=`cat $AMD`
else 
	AMDLIST=$AMD
fi


SUCCESS=""
FAILURE=""
echo -e "AMDs to deploy to:\n${AMDLIST}\n"

AMDADDR=""
#set -x
echo -e "$AMDLIST" | while read AMDADDR; do
	ERR=0

	set -x

	# test if AMD is alive
	echo -e "\nTesting ${AMDADDR}"
	(ping -W ${PINGTO} -c 4 ${AMDADDR} 2>&1 ) > /dev/null 
	ERR=$?
	if [ $ERR -ne 0 ]; then
		echo "Couldn't ping AMD ${AMDADDR}. Skipping"
		FAILURE="${FAILURE}${AMDADDR} ping failed\n"
		continue
	fi

	# upload package
	echo "Uploading to ${AMDADDR}"
	(${SCP} ${OPTSSHARGS} ${SSHKEY} ${DEPLOYPKG} ${SSHUSER}@${AMDADDR}:/tmp 2>&1) > /dev/null
	ERR=$?
	if [ $ERR -ne 0 ]; then
		echo "Couldn't upload ${DEPLOYPKG} to ${AMDADDR}. Skipping"
		FAILURE="${FAILURE}${AMDADDR} upload failed\n"
		continue
	fi

	# deploy package
	echo "Updating ${AMDADDR}"
	OUTPUT="$(${SSH} ${OPTSSHARGS} ${SSHKEY} -f ${SSHUSER}@${AMDADDR} 'uname -a ; cd /tmp ; tar -xjf /tmp/'${DEPLOYPKG}' && '${SUDO}'rpm -'$UPDATEFLG'i /tmp/centosupdate/*.rpm ; SERR=$? ; echo $SERR ' 2>&1 )"
	ERR=`echo -e "$OUTPUT" | tail -n 1`
	if [ $ERR -ne 0 ]; then 
		# failed or if U flag, already up to date
		echo -e "AMD $AMDADDR Deployment Output:\n---\n${OUTPUT}\n---"
		echo "Couldn't deploy on ${AMDADDR}. Skipping"
		FAILURE="${FAILURE}${AMDADDR} deployment failed\n"
		continue
	else
		# all good so restart AMD
		echo "Restarting AMD ${AMDADDR}"
		OUTPUT=$(${SSH} ${OPTSSHARGS} ${SSHKEY} -f ${SSHUSER}@${AMDADDR} ${SUDO}' shutdown -r now ')
	
		SUCCESS="${SUCCESS}${AMDADDR}\n"
	
		continue
	fi

done 

echo -e "\n\n\n"
echo -e "Successful updates:\n${SUCCESS}"
echo -e "Failed updates:\n${FAILURE}"
echo "Done."
