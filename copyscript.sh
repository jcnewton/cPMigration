#!/bin/bash
# Original version written by Phil Stark
# Maintained and updated by Phil Stark and Blaine Motsinger
#
# Version 1.0.4
#
# Purpose:  to find all accounts existing on the Source server that do not exist
# on the destination server, package and transfer those accounts,  and restore
# them on the Destination  server automatically.  This is intended to use either
# in lieu of the WHM tools or as a followup to manually  package accounts that
# otherwise failed in WHM "Copy multiple accounts ..."
#
# usage: run on destination server
# $ sh copyscript <sourceIP>
####################
# This script copies all accounts from the source server that do not exist
# on the destination server already.
# This should always be run on the destination server
# NOTE:  a RSA key should be set up Destination > Source before running
# this script for password-less login.
#############################################

#############################################
# functions
#############################################
print_help() {
    echo 'usage:'
    echo './copyscript -s sourceserver'
    echo
    echo 'required:' 
    echo '-s sourceserver (hostname or ip)'
    echo
    echo 'optional:'
    echo '-p sourceport'
    echo '-h displays this dialogue'
    echo;echo;exit 1
}

#############################################
# get options and checking
#############################################
while getopts ":s:p:h" opt;do
    case $opt in
        s) sourceserver="$OPTARG";;
        p) sourceport="$OPTARG";;
        h) print_help;;
       \?) echo "invalid option: -$OPTARG";echo;print_help;;
        :) echo "option -$OPTARG requires an argument.";echo;print_help;;
    esac
done

if [[ $# -eq 0 || -z $sourceserver ]];then print_help;fi

#############################################
# initial checks
#############################################

# check for root
if [ $EUID -ne 0 ];then
    echo 'copyscript must be run as root'
    echo;exit
fi

#############################################
# options operators
#############################################

# Package accounts on the source server
pkgaccounts=1

# Restore packages on the destination server
restorepkg=1

# Delete cpmove files from the source once transferred to the destination server
removesourcepkgs=0

# Delete cpmove files from the destination server once restored
removedestpkgs=0

#############################################
### Parse a list of accounts that need to be copied
#############################################

# Make working directory
mkdir /root/.copyscript

# grab source accounts list
scp root@$sourceserver:/etc/trueuserdomains /root/.copyscript/.sourcetudomains

# sort source accounts list
sort /root/.copyscript/.sourcetudomains > /root/.copyscript/.sourcedomains

# grab and sort local (destination) accounts list
sort /etc/trueuserdomains > /root/.copyscript/.destdomains

# diff out the two lists,  parse out usernames only and remove whitespace.  Output to copyaccountlist :) 
diff -y /root/.copyscript/.sourcedomains /root/.copyscript/.destdomains | grep \< | awk -F':' '{ print $2 }' | sed -e 's/^[ \t]*//' | awk -F' ' '{ print $1 }' > /root/.copyscript/.copyaccountlist


#############################################
# Process loop
#############################################
i=1
count=`cat /root/.copyscript/.copyaccountlist | wc -l`
for user in `cat /root/.copyscript/.copyaccountlist`
do
		progresspercent=`expr $i / $count` * 100
		echo Processing account $user.  $i/$count \($progresspercent%\)

		# Package accounts on source server (if set)
		if [ $pkgaccounts == 1 ]
			then
			ssh root@$sourceserver "/scripts/pkgacct $user;exit"	
		fi

		# copy (scp) the cpmove file from the source to destination server
		scp root@$sourceserver:/home/cpmove-$user.tar.gz /home/

		# Remove cpmove from source server (if set)
		if [ $removesourcepkgs == 1 ]
			then
			ssh root@$sourceserver "rm -f /home/cpmove-$user.tar.gz ;exit"	
		fi

		# Restore package on the destination server (if set)
		if [ $restorepkg == 1 ]
			then
			/scripts/restorepkg /home/cpmove-$user.tar.gz
		fi

		# Remove cpmove from destination server (if set)
		if [ $removedestpkgs == 1 ]
			then
			rm -f /home/cpmove-$user.tar.gz	
		fi		
		i=`expr $i + 1`
done
