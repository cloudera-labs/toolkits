#!/bin/bash

# This script is for training purposes only and is to be used only
# in support of approved training. The author assumes no liability
# for use outside of a training environments. Unless required by
# applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.

# Title: install_mit_kerberos.sh
# Author: WKD  
# Date: 150715 
# Purpose: Admin script to assist in managing the Hadoop cluster
# and services. Used to install kerberos through out the cluster 

# DEBUG
#set -x
#set -eu
#set >> /root/setvar.txt

# VARIABLES
NUMARGS=$#
DIR=${HOME}
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${DIR}/log/install-kerberos.log

# FUNCTIONS
function usage() {
	echo "Useage: $(basename $0)" 
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

function installKerberos() {
# Install Kerberos server and admin

	sudo yum install -y krb5 krb5-workstation pam_krb5 < /dev/null
}

# MAIN 
# Source functions
callInclude

# Run checks
checkSudo
checkArg

# Run installs
installKerberos
