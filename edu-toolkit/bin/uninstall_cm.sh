#!/bin/bash

# Copyright 2022 Cloudera, Inc.
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

# Title: uninstall_cm.sh
# Author: WKD
# Date: 12JUN22
# Purpose: Uninstall Cloudera Manager. This script will uninstall 
# the Cloudera Manager server, the supporting database, and the
# Cloudera Manager agents. This script must be run on the cmhost.
# A text file, list_host, listing all of the nodes in the cluster, is
# required.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLE
NUMARGS=$#
DIR=${HOME}
HOST=cmhost.example.com
HOST_FILE=${DIR}/conf/list_host.txt
OPTION=$1
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${DIR}/log/uninstall_cm_agent.log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [all|server|database|agent|show]"
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

function pre_list() {
# List actions to complete prior to running the script

	echo
	echo "1. Cloudera Manager Home > Cluster Action > Stop"
	echo "2. Deactivete all Parcels"
	echo "3. Cloudera Manager Home > Parcels > Deactivate"
	echo "4. Cloudera Manager Home > Cluster Action > Delete"
	echo -n "Confirm the clusters is deleted. "
	check_continue	
}

function stop_server() {
# Stop CM and the embedded CM DB.

        sudo systemctl stop cloudera-scm-server
#       sudo systemctl stop cloudera-scm-server-db
}

function remove_server() {
# Use yum to remove CM and the embedded CM DB.

        sudo yum remove -y  cloudera-manager-server
#       sudo yum remove -y cloudera-scm-server-db
}

function stop_database() {
# Stop database.

        sudo systemctl stop mariadb.service
}

function remove_database() {
# Remove database.

        sudo yum remove -y mariadb-server mariadb-client
        sudo rm -r /var/lib/mysql
        sudo rm -r /etc/my.cnf
}

function stop_agent() {
# Stop CM and the CM DB.

   for HOST in $(cat ${HOST_FILE}); do
        ssh -tt ${HOST} "sudo systemctl stop cloudera-scm-supervisord.service"  >> ${LOGFILE} 2>&1
        RESULT=$?
        if [ ${RESULT} -eq 0 ]; then
                    echo "Stop the agent on ${HOST}" | tee -a ${LOGFILE}
        else
                    echo "ERROR: Failed to stop the agent on ${HOST}" | tee -a ${LOGFILE}
        fi
   done
}

function remove_agent() {
# Use yum to remove CM Agent. 

   for HOST in $(cat ${HOST_FILE}); do
        ssh -tt ${HOST} "sudo yum remove -y cloudera-manager-*"  >> ${LOGFILE} 2>&1
        RESULT=$?
        if [ ${RESULT} -eq 0 ]; then
                    echo "Removed the agent on ${HOST}" | tee -a ${LOGFILE}
        			ssh -tt ${HOST} "sudo yum clean all"  >> ${LOGFILE} 2>&1
        else
                    echo "ERROR: Failed to remove the agent on ${HOST}" | tee -a ${LOGFILE}
        fi
   done
}

function clean_agent() {
# Glean out support files for CM Agent. 

   for HOST in $(cat ${HOST_FILE}); do
        ssh -tt ${HOST} "sudo rm /tmp/.scm_prepare_node.lock"  >> ${LOGFILE} 2>&1
        ssh -tt ${HOST} "sudo umount cm_process"  >> ${LOGFILE} 2>&1
        ssh -tt ${HOST} "sudo rm -Rf /usr/share/cmf /var/cache/cloudera* /var/lib/yum/cloudera* /var/log/cloudera* /var/run/cloudera* "  >> ${LOGFILE} 2>&1
        RESULT=$?
        if [ ${RESULT} -eq 0 ]; then
                    echo "Clean the agent on ${HOST}" | tee -a ${LOGFILE}
        else
                    echo "ERROR: Failed to clean the agent on ${HOST}" | tee -a ${LOGFILE}
        fi
   done
}

function show_server() {
# Show status of CM server.

	sudo systemctl status cloudera-scm-server
	sudo systemctl status mariadb.service
}

function run_option() {
# Case statement for options.

    case "${OPTION}" in
        -h | --help)
            usage
            ;;
	all)
	   check_arg 1
	   pre_list
	   stop_server
	   remove_server
	   stop_database
           remove_database
	   stop_agent
 	   remove_agent
	   clean_agent
	   ;;
	cm)
	  check_arg 1
	  pre_list
	  stop_server
	  remove_server
	  ;;
	database)
	  stop_database
	  remove_database
	  ;;
        agent)
           check_arg 1	
	   stop_agent
	   remove_agent 
	   clean_agent
	   ;;
        show)
           check_arg 1
	   show_server 
           ;;
        *)
           usage
           ;;
    esac
}

# MAIN
# Run checks
call_include
check_sudo
setup_log

# Run command
run_option
