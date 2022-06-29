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

# Title: run_remote_node.sh
# Author: WKD
# Date: 210521 
# Purpose: Multipurpose script for basic admin functions.
# connect: Validate connect with ssh"
# reboot: Reboot all systems in host list"
# update: Run yum update all on all host in host list"
# cleanlog: Glean CDP logs in the /var/log directories" 
#  Check the applist.txt file for directories"

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
NUMARGS=$#
DIR=${HOME}
OPTION=$1
INPUT=$2
HOSTS=${DIR}/conf/list_host.txt
APPSLIST=${DIR}/conf/list_app.txt
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${DIR}/log/run-remote-nodes.log

# FUNCTIONS
function usage() {
	echo "Usage: $(basename $0) [cleanlog|connect|reboot|update]" 
	echo "  cleanlog: glean CDP logs in the /var/log directories" 
	echo "  connect: validate connect with ssh"
	echo "  reboot: reboot all systems in host list"
	echo "  update: run yum update all on all hosts in host list"
	exit 
}

function call_include() {
# Test for script and run functions

        if [ -f ${DIR}/bin/include.sh ]; then
                source ${DIR}/bin/include.sh
        else
                echo "ERROR: The file ${DIR}/bin/include.sh not found."
                echo "This required file provides supporting functions."
		exit 1
        fi
}

function run_clean_log() {
# Run a script clean out logs on all nodes

        for HOST in $(cat ${HOSTS}); do
    		while read -r APP; do
                        ssh -tt ${HOST} "sudo rm -r /var/log/${APP}/*" < /dev/null >> ${LOGFILE} 2>&1
                done < ${APPSLIST}
                echo "Cleaned all logs on ${HOST}" | tee -a ${LOGFILE}
        done
}


function run_connect() {
# Rename the host name of the node

        echo "Answer 'yes' if asked to remote connect"

        for HOST in $(cat ${HOSTS}); do
                ssh ${HOST} echo "Testing" > /dev/null 2>&1
                if [ $? = "0" ]; then
                        echo "Connected to ${HOST}"
                else
                        echo "Failed to connect to ${HOST}"
                fi
        done
}

function run_reboot() {
# Run a script on the remote nodes

        for HOST in $(cat ${HOSTS}); do
                echo "Reboot ${HOST}" | tee -a ${LOGFILE}
                ssh -tt ${HOST} "sudo reboot" >> ${LOGFILE} 2>&1
        done
}

function run_update() {
# Run a script on the remote nodes

        for HOST in $(cat ${HOSTS}); do
                ssh -tt ${HOST} "sudo yum -y update" >> ${LOGFILE} 2>&1
                echo "Run yum update on ${HOST}" | tee -a ${LOGFILE}
        done
}

function run_option() {
# Case statement for options

	case "${OPTION}" in
		-h | --help)
			    usage
			    ;;
        cleanlog)
                check_arg 1
                run_clean_log
                ;;
  		connect)
                check_arg 1
                run_connect
	     		;;
        reboot)
                check_arg 1
                run_reboot
                ;;
        update)
                check_arg 1
                run_update
                ;;
		*)
		    	usage
			    ;;
	esac
}

# MAIN
# Source functions
call_include

# Run checks
check_sudo
check_tgt

# Run setups
setup_log ${LOGFILE}

# Run option
run_option

# Review log file
echo "Review log file at ${LOGFILE}"
