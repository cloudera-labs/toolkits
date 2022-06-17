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

# Title: manage_hdfs_users.sh
# Author: WKD
# Date: 180318
# Purpose: Create HDFS users in support of HDP. Add a list of HDFS 
# users from the users.txt file. Create hdfs user working directory 
# and set quotas. 

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
NUMARGS=$#
DIR=${HOME}
OPTION=$1
FILEQ=$2
SPACEQ=$3
USERS=${DIR}/conf/listusers.txt
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${DIR}/log/manage-hdfs-users.log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [add]"
        echo "			     [delete]"
        echo "			     [list]"
        echo "			     [setquota <file_quota> <space_quota>]"
        echo "			     [clearquota]"
        echo "			     [listquota]"
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

function add_user() {
# Add a block of working directories for HDFS users 
# from the users.txt.

	while IFS=: read -r NEWUSER NEWGROUP; do
		echo "Adding working directory for ${NEWUSER}"
		sudo -u hdfs hdfs dfs -mkdir /user/${NEWUSER}
        	sudo -u hdfs hdfs dfs -chown ${NEWUSER}:${NEWGROUP} /user/${NEWUSER}
	done < ${USERS}
}

function delete_user() {
# Delete a block of working directories for HDFS users 
# from the users.txt file.

	while IFS=: read -r NEWUSER NEWGROUP; do
		echo "Deleting working directory for ${NEWUSER} from HDFS."
		sudo -u hdfs hdfs dfs -rm -r -skipTrash /user/${NEWUSER}
	done < ${USERS}
}

function list_user() {
# List hdfs users

        sudo -u hdfs hdfs dfs -ls /user
}

function set_quota() {
# Setting quotas for users from the users.txt file

	while IFS=: read -r NEWUSER NEWGROUP; do
		echo "Setting quotas for ${NEWUSER}"
        	sudo -u hdfs hdfs dfsadmin -setQuota ${FILEQ} /user/${NEWUSER}
        	sudo -u hdfs hdfs dfsadmin -setSpaceQuota ${SPACEQ} /user/${NEWUSER}
	done < ${USERS}
}

function clear_quota() {
# Clearing the quotas for users from the users.txt file

	while IFS=: read -r NEWUSER NEWGROUP; do
		echo "Clearing quotas for ${NEWUSER}"
        	sudo -u hdfs hdfs dfsadmin -clrQuota /user/${NEWUSER}
        	sudo -u hdfs hdfs dfsadmin -clrSpaceQuota /user/${NEWUSER}
	done < ${USERS}
}

function list_quota() {
# Setting quotas for users from the users.txt file

	while IFS=: read -r NEWUSER NEWGROUP; do
		echo "Listing quotas for ${NEWUSER}"
        	sudo -u hdfs hadoop fs -count -q -h /user/${NEWUSER}
	done < ${USERS}
}

function run_option() {
# Case statement for add, delete or list working 
# directories for users

        case "${OPTION}" in
                -h | --help)
                        usage
			;;
                add)
			check_arg 1
                        add_user
			;;
                delete)
			check_arg 1
                        delete_user
			;;
                list)
			check_arg 1
                        list_user
			;;
                setquota)
			check_arg 3
                       	set_quota 
			;;
                clearquota)
			check_arg 1
                       	clear_quota 
			;;
                listquota)
			check_arg 1
                       	list_quota 
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

# Run options
run_option
