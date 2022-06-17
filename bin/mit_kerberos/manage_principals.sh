#!/bin/bash

# This script is for training purposes only and is to be used only
# in support of approved training. The author assumes no liability
# for use outside of a training environments. Unless required by
# applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.

# Title: manage_principals.sh
# Author: WKD
# Date: 1MAR18
# Purpose: Create or delete Linux power users in support of HDP. This 
# script will create and delete users for every node in the node list.

# DEBUG
# set -x
#set -eu
#set >> /root/setvar.txt

# VARIABLES
NUMARGS=$#
DIR=${HOME}
OPTION=$1
USERS=${DIR}/conf/listusers.txt
REALM=CLOUDAIR.LAN
KADMIN=kadmin
PASSWORD=BadPassW0rd!9
DATETIME=$(date +%Y%m%d%H%M)
LOGDIR=${DIR}/log
LOGFILE="${LOGDIR}/add-princs.log"

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [addprincs|delprincs|listprincs]"
        exit 1
}

function callInclude() {
# Test for script and run functions

        if [ -f ${DIR}/sbin/include.sh ]; then
                source ${DIR}/sbin/include.sh
        else
		echo "Include file not found"
        fi
}

function addPrincs() {
#  Add principals

	echo "Creating headless principals"
	while IFS=: read -r PRINC NEWGROUP; do
		sudo kadmin -p ${KADMIN}/admin -w ${PASSWORD} -q "addprinc -pw ${PASSWORD} ${PRINC}@${REALM}" >> ${LOGFILE} 2>&1
	done < ${USERS}
}

function deletePrincs() {
# Delete principals
	
	echo "Deleting headless principals"
	while IFS=: read -r PRINC NEWGROUP; do
		sudo kadmin -p ${KADMIN}/admin -w ${PASSWORD} -q "delprinc -force ${PRINC}@${REALM}" >> ${LOGFILE} 2>&1
	done < ${USERS}
}

function listPrincs() {
# Delete principals
	
	echo "List principals"
	while IFS=: read -r NEWUSER NEWGROUP; do
		sudo kadmin -p ${KADMIN}/admin -w ${PASSWORD} -q "listprincs" 
	done < ${USERS}
}

function runOption() {
# Case statement for add or delete Linux users

        case "${OPTION}" in
                -h | --help)
                        usage
			;;
                addprincs)
			checkArg 1
                        addPrincs
			;;
                delprincs)
			checkArg 1
                        deletePrincs
			;;
                listprincs)
			checkArg 1
                        listPrincs
			;;
                *)
                        usage
			;;
        esac
}

# MAIN
# Source functions
callInclude

# Run checks
checkSudo
checkLogDir
checkFile ${USERS}
checkFile ${HOSTS}

# Run option
runOption
