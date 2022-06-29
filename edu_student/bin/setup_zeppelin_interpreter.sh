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

# Title: template.sh
# Author: WKD
# Date: 06JUN22
# Purpose: Install Zeppelin interpreters for Shell, JDBC, and Livy. 

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLE
NUMARGS=$#
DIR=${HOME}
HOST=edge.example.com
LIST_HOST=${DIR}/conf/list_host.txt
OPTION=$1
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${DIR}/log/setup_zeppelin_interpreter.log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [display|keytab|install]"
        exit
}

function call_include() {
# Test for include script

        if [ -f ${DIR}/bin/include.sh ]; then
                source ${DIR}/bin//include.sh
        else
                echo "ERROR: The file ${DIR}/bin/include.sh not found."
                echo "This required file provides supporting functions."
                exit 1
        fi
}

function display_file() {
# Display the content of the interpreter.json file
	
	FILE=${HOME}/conf/interpreter.json

	cat $FILE
	echo
}

function setup_keytab() {
# Create a static keytab for zeppelin

	ssh -tt ${HOST} "sudo mkdir -p /etc/security/keytabs" >> ${LOGFILE} 2>&1
	ssh -tt ${HOST} "sudo rm /etc/security/keytabs/zeppelin.keytab" >> $${LOGFILE} 2>&1

	export KEYDIR=$(ssh edge.example.com sudo ls -Art /var/run/cloudera-scm-agent/process/ | grep -i zeppelin | tail -n 1)
	echo "The keytab is located in $KEYDIR" >> ${LOGFILE} 2>&1

	ssh -tt ${HOST} "sudo cp /var/run/cloudera-scm-agent/process/$KEYDIR/zeppelin.keytab /etc/security/keytabs/zeppelin.keytab" >> ${LOGFILE} 2>&1
	ssh -tt ${HOST} "sudo chown zeppelin:zeppelin /etc/security/keytabs/zeppelin.keytab" >> ${LOGFILE} 2>&1
}

function install_shell_jar() {
# Install the jar files for the shell interpreter

	SHELLJAR=zeppelin-shell-0.8.2.7.1.7.0-551.jar

	ssh -tt ${HOST} "sudo /opt/cloudera/parcels/CDH/lib/zeppelin/bin/install-interpreter.sh --name shell --artifact /opt/cloudera/parcels/CDH/zeppelin/interprester/sh/${SHELLJAR}" >> ${LOGFILE} 2>&1
	RESULT=$?
	if [ ${RESULT} -eq 0 ]; then
		echo "Install ${SHELLJAR} onto ${HOST}" | tee -a ${LOGFILE}
	else
		echo "ERROR: Failed to install ${SHELLJAR} onto ${HOST}" | tee -a ${LOGFILE}
    fi
}

function push_file() {
# Push a file into remote node.

    FILE=${DIR}/conf/interpreter.json
    OUTPUT=/tmp/interpreter.json

    check_file ${FILE}

	scp -r ${FILE} ${HOST}:${OUTPUT} >> ${LOGFILE} 2>&1
	RESULT=$?
	if [ ${RESULT} -eq 0 ]; then
		echo "Push ${FILE} to ${HOST}" | tee -a ${LOGFILE}
	else        
		echo "ERROR: Failed to push ${FILE} to ${HOST}" | tee -a ${LOGFILE}
	fi
}

function move_file() {
# Move a file into remote node. This is excuted as root.
# The file will have root ownership.

    FILE=/tmp/interpreter.json
    OUTPUT=/var/lib/zeppelin/conf/interpreter.json

	ssh -tt ${HOST} "sudo mv ${FILE} ${OUTPUT}"  >> ${LOGFILE} 2>&1
	RESULT=$?
	if [ ${RESULT} -eq 0 ]; then
		echo "Moved ${FILE} on ${HOST} to location" | tee -a ${LOGFILE}
		echo "Use Cloudera Manager to restart Zeppelin"
	else
		echo "ERROR: Failed to move ${FILE}" | tee -a ${LOGFILE}
	fi
}

function run_option() {
# Case statement for options.

    case "${OPTION}" in
        -h | --help)
            usage
            ;;
        display)
            check_arg 1
			display_file
            ;;
        keytab)
            check_arg 1
			setup_keytab
            ;;
        install)
            check_arg 1	
			install_shell_jar
			push_file
			move_file		
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
setup_log
run_option
