#!/bin/bash

# This script is for training purposes only and is to be used only
# in support of approved training. The author assumes no liability
# for use outside of a training environments. Unless required by
# applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.

# Title: setup-ambari-https.sh
# Author: WKD and Validmir Zlatkin
# Date: 200528
# Purpose: This script setups Ambari to use https. Enabling SSL 
# encryption then requires users to access Ambari through HTTPS at 
# port 8443. Enabling the Ambari truststore allows Ambari views to 
# use SSL

# DEBUG
#set -x
#set -eu
#set >> /root/setvar.txt

# VARIABLE
NUMARGS=$#
DIR=/home/sysadmin
WRKDIR=/tmp
AMBARI_CRT=/etc/security/pki/server.crt
AMBARI_KEY=/etc/security/pki/server.key
KEYPASS="BadPass%1"
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

function installExpect() {
# Install the expect software package

	echo "Install the expect software package" | tee -a ${LOGFILE}
	sudo wget http://mirror.centos.org/centos/7/os/x86_64/Packages/expect-5.45-14.el7_1.x86_64.rpm
    	sudo rpm -q expect || sudo yum install -y expect >> ${LOGFILE} 2>&1
}

function createExpect() {
# Create the expect script for Ambari HTTPS

	echo "Create the expect script for Ambari HTTPS" | tee -a ${LOGFILE}
	cat <<EOF > ${WRKDIR}/ambari-server-https.exp
#!/usr/bin/expect
spawn "/usr/sbin/ambari-server" "setup-security"
expect "Enter choice"
send "1\r"
expect "Do you want to configure HTTPS"
send "y\r"
expect "SSL port"
send "8443\r"
expect "Enter path to Certificate"
send "${AMBARI_CRT}\r"
expect "Enter path to Private Key"
send "${AMBARI_KEY}\r"
expect "Please enter password for Private Key"
send "${KEYPASS}\r"
interact
EOF

	checkFile ${WRKDIR}/ambari-server-https.exp
}

function runExpect() { 
# Run the Ambari HTTPS expect script

	echo "Run the expect script for Ambari HTTPS" | tee -a ${LOGFILE}
       	sudo /usr/bin/expect ${WRKDIR}/ambari-server-https.exp >> ${LOGFILE} 2>&1
	sleep 3
	echo
}

function restartAmbari() {
# Restart the Ambari server and then clean up.

	echo "Restarting Ambari Server for HTTPS" | tee -a ${LOGFILE}
        sudo ambari-server restart >> ${LOGFILE} 2>&1

        while true; do
                if tail -100 /var/log/ambari-server/ambari-server.log | grep -q 'Started Services'; then
                        break
                else
                        echo -n .
                        sleep 3
                fi
        done
	echo "Ambari Server started for HTTPS" | tee -a ${LOGFILE}
}

function deleteExpect() {
# Remove the expect scripts
	if [ -f ${WRKDIR}/ambari-server-https.exp ]; then
    		rm -f ${WRKDIR}/ambari-server-https.exp >> ${LOGFILE} 2>&1
	fi
}

# MAIN
# Source functions
callInclude

# Run checks
checkArg 0
checkSudo

# Run install
installExpect

# Run functions 
createExpect
runExpect
restartAmbari

# Optional clean up
deleteExpect
