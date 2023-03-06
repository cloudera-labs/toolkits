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

# Title: setup_ranger_audit.sh
# Author: WKD
# Date: 17MAR22
# Purpose: Create the HDFS directory /ranger/audit and a directory 
# for every service in the list. Change the ownership of the directory
# to the service owner user. This script does not include all 
# CDP service components. You still have to run the Create Ranger Audit Directory
# action menu option. 

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLE
num_arg=$#
dir=${HOME}
host=cmhost.example.com
host_file=${dir}/conf/listhosts.txt
service_list="atlas hbase hive impala kafka knox solr yarn"
option=$1
logfile=${dir}/log/$(basename $0).log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [OPTION]"
        exit
}

function call_include() {
# Test for include script.

        if [ -f ${dir}/bin/include.sh ]; then
                source ${dir}/bin//include.sh
        else
                echo "ERROR: The file ${dir}/bin/include.sh not found."
                echo "This required file provides supporting functions."
                exit 1
        fi
}

function get_help() {
# Help page

cat << EOF
SYNOPSIS
        setup_ranger_audit.sh [OPTION]

DESCRIPTION
	This tool will build all of the audit directories in HDFS 
	required by ranger.

	-h, --help
		Help page
        -d, --delete
               Delete all HDFS audit directories 
	-l, --list
		List the Ranger audit directories in HDFS
        -m, --make
               	Make all of the required audit directories in HDFS 
EOF
        exit
}

function list_ranger_dir() {
# List the ranger audit directory.

	hdfs dfs -ls /ranger/audit
}

function create_audit_dir() {
# Test for the audit directory and, if required, create it.

    hdfs dfs -test -e /ranger/audit
    RESULT=$(echo $?)

    if [[ "${RESULT}" -eq 1 ]]; then
         hdfs dfs -mkdir -p /ranger/audit
    fi
}

function create_service_dir() {
# Create audit directory for standard services

    for dir in ${service_list}; do
        hdfs dfs -mkdir -p /ranger/audit/${dir}
        hdfs dfs -chown ${dir}:${dir} /ranger/audit/${dir}
        hdfs dfs -chmod 0755 /ranger/audit/${dir}
    done
}

function create_hdfs_dir() {
# Create the hdfs audit directory. This is an exception as the
# user is different the directory name.

    dir=hdfs
    SERVICE_GROUP=supergroup

     hdfs dfs -mkdir -p /ranger/audit/${dir}
     hdfs dfs -chown ${dir}:${SERVICE_GROUP} /ranger/audit/${dir}
     hdfs dfs -chmod 0755 /ranger/audit/${dir}
}

function create_infra_dir() {
# Create the solr_infra audit directory. This is an exception as the
# user is different the directory name.

    dir=solr-infra
    SERVICE_USER=solr

     hdfs dfs -mkdir -p /ranger/audit/${dir}
     hdfs dfs -chown ${SERVICE_USER}:${SERVICE_USER} /ranger/audit/${dir}
     hdfs dfs -chmod 0755 /ranger/audit/${dir}
}

function create_kms_dir() {
# Create the solr_infra audit directory. This is an exception as the
# user is different the directory name.

    dir=kms
    SERVICE_USER=rangerkms

     hdfs dfs -mkdir -p /ranger/audit/${dir}
     hdfs dfs -chown ${SERVICE_USER}:${dir} /ranger/audit/${dir}
     hdfs dfs -chmod 0755 /ranger/audit/${dir}
}

function delete_audit_dir() {
# Delete the ranger audit directory.

	echo -n "Confirm delete. "
	check_continue
	hdfs dfs -rm -r -skipTrash /ranger/audit
}
function run_option() {
# Case statement for options.

	case "${option}" in
		-h | --help)
			get_help
			;;
		-d | --delete)
			check_arg 1
			delete_audit_dir
			;;
		-l | --list)
			check_arg 1
			list_ranger_dir
			;;
		-m | --make)
			check_arg 1	
			echo running...
			create_audit_dir
			create_hdfs_dir
			create_service_dir
			create_infra_dir
			create_kms_dir
			;;
		*)
			usage
			;;
	esac
}

function main() {

	# Run checks
	call_include
	check_tgt
	check_sudo

	# Run command
	run_option

	# Review log file
	#echo "Review log file at ${logfile}"
}

#MAIN
main "$@"
exit 0
