#!/bin/bash

# This script is for training purposes only and is to be used only
# in support of approved training. The author assumes no liability
# for use outside of a training environments. Unless required by
# applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.

# Title: setup-ambari-ssl.sh
# Author: WKD
# Date: 1MAR18
# Purpose: This script setups Ambari HTTPS and truststore.


# DEBUG
#set -x
#set -eu
#set >> /root/setvar.txt

# VARIABLE
NUMARGS=$#
DIR=/home/sysadmin
TRUSTSTOREPASS=BadPass%1
DATETIME=$(date +%Y%m%d%H%M)
LOGDIR=/home/sysadmin/log
LOGFILE=${LOGDIR}/setup-ambari-ssl.log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0)" 
        exit
}

function callInclude() {
# Test for script and run functions

        if [ -f ${DIR}/sbin/include.sh ]; then
                source ${DIR}/sbin/include.sh
        else
                echo "ERROR: The file ${DIR}/sbin/include.sh not found."
                echo "This required file provides supporting functions."
                exit 1
        fi

}

function importTruststore(){
# Import the server.crt file into the truststore

	sudo keytool -import -noprompt -file /etc/security/pki/server.crt -alias ambari-server -keystore /etc/security/truststores/truststore.jks -storepass "${TRUSTSTOREPASS}"
}

function setupTruststore() {
# setup the truststore for Ambari server views

	sudo ambari-server setup-security \
		--security-option=setup-truststore \
		--truststore-reconfigure \
		--truststore-type=jks \
		--truststore-path=/etc/security/truststores/truststore.jks \
		--truststore-password="${TRUSTSTOREPASS}"
}

function restartAmbari() {
# Restart the Ambari server and then clean up.

        echo "Restarting Ambari Server for truststore" | tee -a ${LOGFILE}
        sudo ambari-server restart >> ${LOGFILE} 2>&1

        while true; do
                if tail -100 /var/log/ambari-server/ambari-server.log | grep -q 'Started Services'; then
                        break
                else
                        echo -n .
                        sleep 3
                fi
        done
        echo "Ambari Server started for truststore" | tee -a ${LOGFILE}
}

# MAIN
# Source functions
callInclude

# Run checks
checkArg 0
checkSudo

# Run functions 
importTruststore
setupTruststore
restartAmbari
