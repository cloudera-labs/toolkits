#!/bin/bash

# This script is for training purposes only and is to be used only
# in support of approved training. The author assumes no liability
# for use outside of a training environments. Unless required by
# applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.

# Name: manage_principal.sh
# Author: WKD
# Date:  140318
# Purpose: Used to create principals for Kerberos. This then
# creates and distributes the keytabs for the principal.
# CAUTION: This can be tricky if you are creating principals for 
# hyphenated users such as hive-webhcat. 
# IMPORTANT: The keytab must be placed into the correct conf directory. 
# In HDP this will be /etc/security/keytabs.

# DEBUG
#set -x
#set -eu
#set >> /root/setvar.txt

# VARIABLES
NUMARGS=$#
DIR=${HOME}
HOSTS=${DIR}/conf/listhosts.txt
OPTION=$1
KADMIN=kadmin
USER=$2
REALM=$3
PASSWORD=$4
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${DIR}/log/manage-principal.log

# FUNCTIONS
function usage() {
	echo "Usage: $(basename $0) add|delete [user] [REALM] [kadmin-password]"
	exit 1
}

function callInclude() {
# Test for script and run functions

        if [ -f ${DIR}/sbin/include.sh ]; then
                source ${DIR}/sbin/include.sh
        else
                echo "ERROR: The file ${DIR}/sbin/include.sh not found."
                echo "This required file provides supporting functions."
        fi
}

function addPrinc() {
# Create a principal for each host in the cluster.

	for HOST in $(cat $HOSTS); do
		echo "Creating principal ${USER} for ${HOST}"
		sudo kadmin -p ${KADMIN}/admin -w ${PASSWORD} -q "addprinc -randkey ${USER}/${HOST}@${REALM}"
	done
}

function createKeytab() {
# Create a keytab for each host in the cluster.

	for HOST in $(cat $HOSTS); do
		echo "Creating ${USER} keytab for ${HOST}"
   		sudo kadmin -p ${KADMIN}/admin -w ${PASSWORD} -q "xst -k /tmp/${USER}.${HOST}.keytab ${USER}/${HOST}@${REALM}"
		sudo chmod 666 /tmp/${USER}.${HOST}.keytab
	done
}

function distroKeytab() {
# Distribute the keytabs to every node.
	
	for HOST in $(cat $HOSTS); do
		echo "Distributing ${USER} keytab to ${HOST}"
   		scp /tmp/${USER}.${HOST}.keytab ${HOST}:/tmp/${USER}.keytab
		ssh ${HOST} -C "sudo mv /tmp/${USER}.keytab /etc/security/keytabs/${USER}.keytab" < /dev/null
		ssh ${HOST} -C "sudo chown ${USER}:hadoop /etc/security/keytabs/${USER}.keytab" < /dev/null
		ssh ${HOST} -C "sudo chmod 600 /etc/security/keytabs/${USER}.keytab" < /dev/null
		sudo rm /tmp/${USER}.${HOST}.keytab
	done
}

function deletePrinc() {
# Create a principal for each host in the cluster.

	for HOST in $(cat $HOSTS); do
		echo "Deleting principal ${USER} from ${HOST}"
		sudo kadmin -p ${KADMIN}/admin -w ${PASSWORD} -q "delprinc -force ${USER}/${HOST}@${REALM}"
	done
}

function deleteKeytab() {
# Distribute the keytabs to every node.
	
	for HOST in $(cat $HOSTS); do
		echo "Deleting ${USER} keytab from ${HOST}"
		ssh ${HOST} -C "sudo rm /etc/security/keytabs/${USER}.keytab" < /dev/null
	done
}

function checkKeytab() {
# Test the Hadoop keytab for each HOST in the cluster.
	
	for HOST in $(cat $HOSTS); do
		echo "Listing ${USER} keytab on ${HOST}"
		ssh ${HOST} -C "sudo klist -ket /etc/security/keytabs/${USER}.keytab" 
	done
}

function runOption() {
# Case statement for options

        case "${OPTION}" in
                -h | --help)
                        usage
                        ;;
                add)
                        checkArg 4
                        addPrinc
			createKeytab
			distroKeytab
			checkKeytab
                        ;;
                delete)
                        checkArg 4
                        deletePrinc
			deleteKeytab
                        ;;
                *)
                        usage
                        ;;
        esac
}


#MAIN
# Source functions
callInclude

# Run checks
checkSudo
checkFile ${HOSTS}

# Run option
runOption
