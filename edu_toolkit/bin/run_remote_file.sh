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
num_arg=$#
option=$1
input=$2
output=$3
dir=${HOME}
host=${dir}/conf/list_host.txt
logfile=${dir}/log/$(basename $0).log

# FUNCTIONS
function usage() {
# Usage statement

	echo "Usage: $(basename $0) [OPTION]" 
	echo "Usage: $(basename $0) [OPTION] [FILE]" 
	echo "Usage: $(basename $0) [OPTION] [FILE] [FILE]" 
	exit
}

function get_help() {
# Help 

cat << EOF
SYNOPSIS
	run_remote_file.sh [OPTION] [FILE]
	run_remote_file.sh [OPTION] [FILE] [FILE]

DESCRIPTION
	This tool manages remote files. This tool will push files
	to a list of hosts, it will also run, move, and delete the
	files.

	-h, --help
		Help page
	-d, --delete <remote_path/file>
		Delete this file from all hosts
	-e, --extract <remote_path/tar-file> <remote_path>
		Extract a tar file on all hosts
	-l, --list <remote_path/file> 
		List the file on all hosts
	-m, --move <remote_path/file> <remote_path/file> 
		Move or rename a file on all hosts
	-p, --push <local_path/file> <remote_path/file> 
		Push a file to all hosts
	-r, --run <remote_path/script>
		Run an shell script on all hosts

INSTRUCTIONS
	List cluster's hosts
	$ cat /home/user/conf/list_host.txt

	Run a shell script on all hosts
	$ run_remote_file.sh --push /home/user/script.sh /tmp/script.sh
	$ run_remote_file.sh --list /tmp
	$ run_remote_file.sh --run /tmp/script.sh
	$ run_remote_file.sh --delete /tmp/script.sh

	Replace a configuration file
	$ run_remote_file.sh --push /home/user/conf/config.cnf /tmp/config.cnf
	$ run_remote_file.sh --move /tmp/config.cnf /etc/conf/config.cnf 
EOF
exit
}

function call_include() {
# Calls include script to run functions

        if [ -f ${dir}/bin/include.sh ]; then
                source ${dir}/bin/include.sh
        else
                echo "ERROR: The file ${dir}/bin/include.sh not found."
                echo "This required file provides supporting functions."
		exit 1
        fi
}

function delete_file() {
# Command to delete a file on a remote host.

	remote_file=${input}

	for host in $(cat ${host}); do
		ssh -tt ${host} "sudo rm -r ${remote_file}" < /dev/null >> ${logfile} 2>&1
		result=$?
		if [ ${result} -eq 0 ]; then
			echo "Delete ${remote_file} on ${host}" | tee -a ${logfile}
		else
                	echo "ERROR: Failed to remove ${remote_file} on ${host}" | tee -a ${logfile}
		fi
        done
}

function extract_tar() {
# Extract a tar file in the working directory.

	remote_file=${input}
	dir=${output}

	for host in $(cat ${host}); do
		ssh -tt ${host} "sudo tar xf ${remote_file} -C ${dir}"  >> ${logfile} 2>&1
		result=$?
		if [ ${result} -eq 0 ]; then
			echo "Run tar extract ${remote_file} on ${host}" | tee -a ${logfile}
		else
			echo "ERROR: Failed to tar extract ${remote_file} on ${host}" | tee -a ${logfile}
		fi
	done 
}

function list_file() {
# List a file into remote node.

	remote_file=${input}

        for host in $(cat ${host}); do
		ssh -tt ${host} "ls ${remote_file}"  
        done
}

function move_file() {
# Move a file into remote node. This is excuted as root.
# The file will have root ownership.

	mv_file=${input}
	remote_file=${output}

        for host in $(cat ${host}); do
		ssh -tt ${host} "sudo mv ${mv_file} ${remote_file}"  >> ${logfile} 2>&1
		result=$?
		if [ ${result} -eq 0 ]; then
                	echo "Move ${mv_file} to ${host}" | tee -a ${logfile}
		else
                	echo "ERROR: Failed to move ${mv_file}" | tee -a ${logfile}

		fi
        done
}

function push_file() {
# Push a file into remote node.

	local_file=${input}
	remote_file=${output}

	check_file ${local_file}

        for host in $(cat ${host}); do
                scp -r ${local_file} ${host}:${remote_file} >> ${logfile} 2>&1
		result=$?
		if [ ${result} -eq 0 ]; then
                	echo "Push ${local_file} to ${host}" | tee -a ${logfile}
		else
                	echo "ERROR: Failed to push ${local_file} to ${host}" | tee -a ${logfile}
		fi
        done
}

function run_script() {
# Run a script on a remote node

	remote_file=${input}
	
	echo "Begin installing, this takes time"

        for host in $(cat ${host}); do
                ssh -tt ${host} "sudo ${remote_file}" < /dev/null >> ${logfile} 2>&1
		result=$?
		if [ ${result} -eq 0 ]; then
                	echo "Run ${remote_file} on ${host}" | tee -a ${logfile}
		else
                	echo "ERROR: Failed to run ${remote_file} on ${host}" | tee -a ${logfile}
		fi
        done
}


function run_option() {
# Case statement for options.

	case "${option}" in
		-h | --help)
			get_help
			;;
		-d | --delete)
			check_arg 2
			delete_file
			;;
		-e | --extract)
			check_arg 3
			extract_tar
			;;
		-l | --list)
			check_arg 2
			list_file
			;;
		-m | --move)
			check_arg 3
			move_file
			;;
		-p | --push)
			check_arg 3
			push_file
			;;
		-r | --run)
			check_arg 2
			run_script
			;;
		*)
			usage
			;;
	esac
}

function main() {

	# Source functions
	call_include

	# Run checks
	check_sudo

	# Run setups
	setup_log ${logfile}

	# Run option
	run_option

	# Review log file
	echo "Review log file at ${logfile}"
}

#MAIN
main "$@"
exit 0
