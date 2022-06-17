#!/bin/bash

# Copyright 2021 Cloudera, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Disclaimer
# This script is for training purposes only and is to be used only
# in support of approved training. The author assumes no liability
# for use outside of a training environments. Unless required by
# applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.

# Title: run_jssecacerts.sh
# Author: WKD
# Date: 17MAR22
# Purpose: Run commands to create the jssecacerts file. This file is
# used by Auto-TLS when deploying Cloudera Manager as the root CA. 
# Import the in_cluster truststore into the jssecacerts truststore.
# The jssecacerts truststore should then be distributed to all hosts.
# This is used as a work around for the yarn_kms issue.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLE
NUMARGS=$#
DIR=${HOME}
HOST=cmhost.example.com
HOST_FILE=${DIR}/conf/listhosts.txt
OPTION=$1
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${DIR}/log/run_beeline.log
PASSWORD="BadPass@1"
WORK_DIR=${JAVA_HOME}/jre/lib/security

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [create|delete|import|show]"
	echo "    create - creates jssecacerts.pem"
	echo "    delete - delete all jssecacerts files"
	echo "    import - import the in_custer truststore"
	echo "    show   - print out jssecacerts"
        exit
}

function call_include() {
# Test for include script.

        if [ -f ${DIR}/bin/include.sh ]; then
                source ${DIR}/bin//include.sh
        else
                echo "ERROR: The file ${DIR}/bin/include.sh not found."
                echo "This required file provides supporting functions."
                exit 1
        fi
}

function create_jssecacerts() {
# Create the jssecacerts file.

	sudo cp ${WORK_DIR}/cacerts ${WORK_DIR}/jssecacerts
	sudo keytool -storepasswd -keystore ${WORK_DIR}/jssecacerts -storepass changeit -new ${PASSWORD}
	sudo keytool -importkeystore -srckeystore ${WORK_DIR}/jssecacerts -srcstorepass ${PASSWORD} -deststoretype PKCS12 -destkeystore ${WORK_DIR}/jssecacerts.p12 -deststorepass ${PASSWORD}
	sudo openssl pkcs12 -in ${WORK_DIR}/jssecacerts.p12 -passin pass:${PASSWORD} -out ${WORK_DIR}/jssecacerts.pem
}

function delete_jssecacerts() {
# Describe function.

        echo -n "Confirm delete. "
        check_continue

	if [ -f "${WORK_DIR}/jssecacerts" ]; then
		sudo rm ${WORK_DIR}/jssecacerts ${WORK_DIR}/jssecacerts.p12 ${WORK_DIR}/jssecacerts.pem
	else
		echo "The jssecacerts does not exist"
	fi
}

function import_jssecacerts() {
# Describe function.

	sudo keytool -import -keystore ${WORK_DIR}/jssecacerts -storepass ${PASSWORD} -alias cmrootca-0 -file /var/lib/cloudera-scm-agent/agent-cert/cm-auto-in_cluster_ca_cert.pem
}

function show_jssecacerts() {
# Describe function.

	sudo keytool -printcert -v -file ${WORK_DIR}/jssecacerts.pem
}

 function run_option() {
# Case statement for options.

    case "${OPTION}" in
        -h | --help)
            usage
            ;;
        create)
            check_arg 1	
	    create_jssecacerts
            ;;
        delete)
            check_arg 1	
	    delete_jssecacerts
            ;;
        import)
            check_arg 1	
	    import_jssecacerts
            ;;
        show)
            check_arg 1
	    show_jssecacerts
            ;;
        *)
            usage
            ;;
    esac
}

# MAIN
# Run checks
call_include
check_tgt
check_sudo

# Run command
run_option
