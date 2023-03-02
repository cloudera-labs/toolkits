#!/bin/sh

# This script is for training purposes only and is to be used only
# in support of approved training. The author assumes no liability
# for use outside of a training environments. Unless required by
# applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.
#
# Title: rollback-ssl.sh
# Author:  WKD
# Date: 200524
# Purpose: Master script for rolling back the changes from the generate-ssl-hdp.sh script. This is used during troubleshooting.

# DEBUG
#set -x
#set -eu
#set >> /root/setvar.txt

# VARIABLES
NUMARGS=$#
DIR=/tmp/hdp-ssl
AUTHDIR=auth
KEYSDIR=keys

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0)"
        exit 2
}

function checkRoot() {
# Testing for sudo access to root

        if [ "$EUID" -ne 0 ]; then
                echo "ERROR: This script must be run as root" | tee -a ${LOGFILE}
                usage
        fi
}

function removeDir() {
# Run the certificate generator for local authority and for Ranger
	
	cd ${DIR}
	
	rm -r ${KEYSDIR}
	rm -r /etc/security/keystores /etc/security/truststores /etc/security/pki 
}

function copyCacerts() {

	cp ${AUTHDIR}/cacerts /usr/java/default/jre/lib/security/cacerts
	cp ${AUTHDIR}/cacerts /etc/pki/ca-trust/extracted/java/cacerts
	cp ${AUTHDIR}/cacerts /etc/pki/java/cacerts
}

# MAIN
checkRoot
removeDir
copyCacerts
