#!/bin/bash

# Copyright 2023 Cloudera, Inc.
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

# Title: push_wildcard.sh
# Author: WKD
# Date: 07APR23
# Purpose: Push wildcard certs to the ECS master.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLE
num_arg=$#
dir=${HOME}
ecs_master=ecs-1.example.com
option=$1
domain_name=$2
cert_name=$3
logfile=${dir}/log/$(basename $0).log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [OPTION] <domain_name> <cert_name>"
        exit
}

function get_help() {
# Help page

cat << EOF
SYNOPSIS
	script_name.sh [OPTION} <domain_name> <cert_name>

DESCRIPTION
	Detailed explaination. 

	-h, --help
		help page
	-p, --push <domain_name> <cert_name>
		Push the certificate to the ECS master

INSTRUCTION

	push_wildcard.sh --push sam-lon03 cloudsale

EOF
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

function create_dir() {
# Description 

	cert_dir=/opt/pvc/${domain_name}/security/pki

	ssh -t ${ecs_master} sudo ls ${cert_dir} 2>&1
	ans=$?

	if [ ! ${ans} -eq 0 ]; then
		ssh -t ${ecs_master} sudo mkdir -p /opt/pvc/${domain_name}/security/pki
	fi
}

function push_key() {

	cert_dir=/opt/pvc/${domain_name}/security/pki
	key_file=${cert_name}.key

	if [ -f ${cert_dir}/${key_file} ]; then
		sudo chmod 666 ${cert_dir}/${key_file}
		sudo scp ${cert_dir}/${key_file} ${ecs_master}:/tmp/${key_file}
		ssh -t ${ecs_master} "sudo mv /tmp/${key_file} ${cert_dir}/${key_file}"
		ssh -t ${ecs_master} "sudo chmod 440 ${cert_dir}/${key_file}"
	fi 
}

function push_cert() {

	cert_dir=/opt/pvc/${domain_name}/security/pki
	cert_file=${cert_name}.crt

	if [ -f ${cert_dir}/${cert_file} ]; then
		sudo scp ${cert_dir}/${cert_file} ${ecs_master}:/tmp
		ssh -t ${ecs_master} "sudo  mv /tmp/${cert_file} ${cert_dir}/${cert_file}"
	fi 
}

function run_option() {
# Case statement for options.

    case "${option}" in
        -h | --help)
            get_help
            ;;
        -p |--push)
            check_arg 3
			create_dir
			push_key
			push_cert
            ;;
        *)
            usage
            ;;
    esac
}

function main() {

	# Run checks
	call_include
	#check_tgt
	check_sudo

	# Run command
	run_option

	# Review log file
	#echo "Review log file at ${logfile}"
}

#MAIN
main "$@"
exit 0
