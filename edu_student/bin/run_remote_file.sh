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

# This script is for training purposes only and is to be used only
# in support of approved training. The author assumes no liability
# for use outside of a training environments. Unless required by
# applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.

# Title: run_remote_file.sh
# Author: WKD
# Date: 1MAR14
# Purpose: This script is used to manage files on remote nodes.
# Setup the list_host file with all nodes in the cluster. This script 
# will delete files, push files, move files, and extract a tar file on 
# all listed remote nodes. The push file function copies files as the 
# current user. Use the move file function to move a file into a
# directory owned by root.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
NUMARGS=$#
DIR=${HOME}
HOSTS=${DIR}/conf/list_host.txt
OPTION=$1
INPUT=$2
OUTPUT=$3
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${DIR}/log/run-remote-file.log

# FUNCTIONS
function usage() {
	echo "Usage: $(basename $0) [options]" 
        echo "                          [delete <remote_path/file>]"
        echo "                          [extract <remote_path/tar-file> <remote_path>]"
	echo "                          [list <remote_path/file>]" 
	echo "                          [move <remote_path/file> <remote_path/file>]" 
	echo "                          [push <local_path/file> <remote_path/file>]" 
        echo "                          [run <remote_path/script>]"
	exit 
}

function call_include() {
# Calls include script to run functions

        if [ -f ${DIR}/bin/include.sh ]; then
                source ${DIR}/bin/include.sh
        else
                echo "ERROR: The file ${DIR}/bin/include.sh not found."
                echo "This required file provides supporting functions."
		exit 1
        fi
}

function delete_file() {
# Command to delete a file on a remote host.

	FILE=${INPUT}

	for HOST in $(cat ${HOSTS}); do
		ssh -tt ${HOST} "sudo rm -r ${FILE}" < /dev/null >> ${LOGFILE} 2>&1
		RESULT=$?
		if [ ${RESULT} -eq 0 ]; then
			echo "Delete ${FILE} on ${HOST}" | tee -a ${LOGFILE}
		else
                	echo "ERROR: Failed to remove ${FILE} on ${HOST}" | tee -a ${LOGFILE}
		fi
        done
}

function extract_tar() {
# Extract a tar file in the working directory.

	FILE=${INPUT}
	DIR=${OUTPUT}

	for HOST in $(cat ${HOSTS}); do
		ssh -tt ${HOST} "sudo tar xf ${FILE} -C ${DIR}"  >> ${LOGFILE} 2>&1
		RESULT=$?
		if [ ${RESULT} -eq 0 ]; then
			echo "Run tar extract ${FILE} on ${HOST}" | tee -a ${LOGFILE}
		else
			echo "ERROR: Failed to tar extract ${FILE} on ${HOST}" | tee -a ${LOGFILE}
		fi
	done 
}

function list_file() {
# List a file into remote node.

	FILE=${INPUT}

        for HOST in $(cat ${HOSTS}); do
		ssh -tt ${HOST} "ls ${FILE}"  
        done
}

function move_file() {
# Move a file into remote node. This is excuted as root.
# The file will have root ownership.

	FILE=${INPUT}
	OUTPUT=${OUTPUT}

        for HOST in $(cat ${HOSTS}); do
		ssh -tt ${HOST} "sudo mv ${FILE} ${OUTPUT}"  >> ${LOGFILE} 2>&1
		RESULT=$?
		if [ ${RESULT} -eq 0 ]; then
                	echo "Push ${FILE} to ${HOST}" | tee -a ${LOGFILE}
		else
                	echo "ERROR: Failed to move ${FILE}" | tee -a ${LOGFILE}

		fi
        done
}

function push_file() {
# Push a file into remote node.

	FILE=${INPUT}
	OUTPUT=${OUTPUT}

	check_file ${FILE}

        for HOST in $(cat ${HOSTS}); do
                scp -r ${FILE} ${HOST}:${OUTPUT} >> ${LOGFILE} 2>&1
		RESULT=$?
		if [ ${RESULT} -eq 0 ]; then
                	echo "Push ${FILE} to ${HOST}" | tee -a ${LOGFILE}
		else
                	echo "ERROR: Failed to push ${FILE} to ${HOST}" | tee -a ${LOGFILE}
		fi
        done
}

function run_script() {
# Run a script on a remote node

	FILE=${INPUT}
	
	echo "Begin installing, this takes time"

        for HOST in $(cat ${HOSTS}); do
                ssh -tt ${HOST} "sudo ${FILE}" < /dev/null >> ${LOGFILE} 2>&1
		RESULT=$?
		if [ ${RESULT} -eq 0 ]; then
                	echo "Run ${FILE} on ${HOST}" | tee -a ${LOGFILE}
		else
                	echo "ERROR: Failed to run ${FILE} on ${HOST}" | tee -a ${LOGFILE}
		fi
        done
}


function run_option() {
# Case statement for options.

	case "${OPTION}" in
		-h | --help)
			usage
			;;
                delete)
                        check_arg 2
                        delete_file
			;;
                extract)
                        check_arg 3
                        extract_tar
			;;
                list)
                        check_arg 2
                        list_file
			;;
                move)
                        check_arg 3
                        move_file
			;;
  		push)
                        check_arg 3
                        push_file
			;;
                run)
                        check_arg 2
                        run_script
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

# Run setups
setup_log ${LOGFILE}

# Run option
run_option

# Review log file
echo "Review log file at ${LOGFILE}"
