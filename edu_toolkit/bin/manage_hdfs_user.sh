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

# Title: manage_hdfs_accounts.sh
# Author: WKD
# Date: 180318
# Purpose: Create HDFS user in support of HDP. Add a list of HDFS 
# user from the user.txt file. Create hdfs user working directory 
# and set quotas. This script expects the cluster to be using 
# Kerberos.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
num_arg=$#
dir=${HOME}
option=$1
adminuser=allan_admin
password=BadPass@1
file_quota=$2
space_quota=$3
user=${dir}/conf/list_user.txt
logfile=${dir}/log/$(basename $0).log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [OPTION]"
        echo "Usage: $(basename $0) [OPTION] [INPUT] [INPUT]"
	exit
}

function get_help() {
# help page

cat << EOF
SYNOPSIS
	manage_hdfs_accounts.sh [OPTION]
	manage_hdfs_account.sh [OPTION] [INPUT] [INPUT]

DESCRIPTION
	Manage HDFS users by creating hdfs user directories and setting quotas.
	This tool depends on a text file listing the users and groups.

	-h, --help
		Help page
	-a, --add
		Add users to HDFS
	-d, --delete
		Delete users from HDFS
	-l, --list
		List all HDFS users
	-s, --setquota <file_quota> <space_quota>
		Set a file quota and a space quota on all users
		The file quota is a hard limit of the number of directories and files.
		The space quota is a hard limit of the total size of all of the files
		under the directory. The space quota takes replication into account.
		Use a postfix to identity the byte size. 600m for 600 megabytes, 20g
		for 20 gigabytes, and 2t for 2 terabytes.  
	-c, --clearquota
		Clear all quotas on all users
	-q, --quota
		List all quotas
EOF
        exit 
}

function call_include() {
# Test for script and run functions

        if [ -f ${dir}/bin/include.sh ]; then
                source ${dir}/bin/include.sh
        else
                echo "ERROR: The file ${dir}/bin/include.sh not found."
                echo "This required file provides supporting functions."
		exit 1
        fi
}

function add_user() {
# Add a block of working directories for HDFS user 
# from the user.txt.

	echo "Adding working directory for:"
	while IFS=: read -r new_user new_group; do
		echo "    ${new_user}"
		echo ${password} | su -l ${adminuser} -c "hdfs dfs -mkdir /user/${new_user}" >> ${logfile} 2>&1
        	echo ${password} | su -l ${adminuser} -c "hdfs dfs -chown ${new_user}:${new_group} /user/${new_user}" >> ${logfile} 2>&1
	done < ${user}
}

function delete_user() {
# Delete a block of working directories for HDFS user 
# from the user.txt file.

	echo "Deleting working directory for:"
	while IFS=: read -r new_user new_group; do
		echo "    ${new_user}"
		echo ${password} | su -l ${adminuser} -c "hdfs dfs -rm -r -skipTrash /user/${new_user}" >> ${logfile} 2>&1
	done < ${user}
}

function list_user() {
# List hdfs user

        echo ${password} | su -l ${adminuser} -c "hdfs dfs -ls /user" | tee -a ${logfile} 
}

function set_quota() {
# Setting quotas for user from the user.txt file

	echo "Setting quotas for:"
	while IFS=: read -r new_user new_group; do
		echo "    ${new_user}"
        	echo ${password} | su -l ${adminuser} -c "hdfs dfsadmin -setQuota ${file_quota} /user/${new_user}" >> ${logfile} 2>&1
        	echo ${password} | su -l ${adminuser} -c "hdfs dfsadmin -setSpaceQuota ${space_quota} /user/${new_user}" >> ${logfile} 2>&1
	done < ${user}
}

function clear_quota() {
# Clearing the quotas for user from the user.txt file

	echo "Clearing quotas for:"
	while IFS=: read -r new_user new_group; do
		echo "    ${new_user}"
        	echo ${password} | su -l ${adminuser} -c "hdfs dfsadmin -clrQuota /user/${new_user}" >> ${logfile} 2>&1
        	echo ${password} | su -l ${adminuser} -c "hdfs dfsadmin -clrSpaceQuota /user/${new_user}" >> ${logfile} 2>&1
	done < ${user}
}

function list_quota() {
# Setting quotas for user from the user.txt file

       	hdfs -count -q  -v /user/allan_admin 
	while IFS=: read -r new_user new_group; do
        	hdfs dfs -count -q -h /user/${new_user} 
	done < ${user}
}

function run_option() {
# Case statement for add, delete or list working 
# directories for user

	case "${option}" in
		-h | --help)
			get_help
			;;
		-a | --add)
			check_arg 1
			add_user
			;;
		-d | --delete)
			check_arg 1
			delete_user
			;;
		-l | --list)
			check_arg 1
			list_user
			;;
		-s | --setquota)
			check_arg 3
			set_quota 
			;;
		-c | --clearquota)
			check_arg 1
			clear_quota 
			;;
		-q | --quota)
			check_arg 1
			list_quota 
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
	check_file ${dir}/conf/list_user.txt
	setup_log

	# Run options
	run_option

	# Review log file
	#echo "Review log file at ${logfile}"
}

#MAIN
main "$@"
exit 0
