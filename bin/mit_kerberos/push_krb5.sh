#!/bin/bash

# This script is for training purposes only and is to be used only
# in support of approved training. The author assumes no liability
# for use outside of a training environments. Unless required by
# applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.

# Title: push_krb5.sh
# Author: WKD
# Date: 150827
# Purpose: Push Kerberos configuration file to cluster.

# DEBUG
#set -x
#set -eu
#set >> /root/setvar.txt

# VARIABLES
NUMARGS=$#
DIR=${HOME}
HOSTS=${DIR}/conf/listhosts.txt
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${DIR}/log/push-krb5.log

# FUNCTIONS
function usage() {
    	echo "Usage: sudo $(basename $0)" 
    	exit 1 
}

function callInclude() {
# Test for script and run functions

        if [ -f ${DIR}/sbin/include.sh ]; then
                source ${DIR}/sbin/include.sh
        else
                echo "ERROR: The file ${DIR}/sbin/functions not found."
                echo "This required file provides supporting functions."
        fi
}

function pushKrb5Conf() {
# Push the Kerberos config file to all nodes

	for HOST in $(cat ${HOSTS}); do
        	echo "Copy Kerberos configs to ${HOST}" 
        	scp ${DIR}/conf/krb5.conf ${HOST}:${HOME}/krb5.conf 
		ssh -tt ${HOST} -C "sudo mv ${HOME}/krb5.conf /etc/krb5.conf"
    	done
}

# MAIN
# Source functions
callInclude

# Run checks
checkSudo
checkArg 0

# Push file
pushKrb5Conf
