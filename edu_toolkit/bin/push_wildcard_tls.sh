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

# Title: push_wildcard_tls.sh
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
option=$1
host_name=$2
cluster_name=$3
cert_name=$4
logfile=${dir}/log/$(basename $0).log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [OPTION] <host_name> <cluster_name> <cert_name>"
        exit
}

function get_help() {
# Help page

cat << EOF
SYNOPSIS
	push_wildcard_lts.sh [OPTION} <host_name> <cluster_name> <cert_name>

DESCRIPTION
	This tool will push the certificate and the key to the ECS master. The
	default location is /opt/<host_name>/security/pki.

	-h, --help
		help page
	-p, --push <host_name> <cluster_name> <cert_name>
		Push the certificate to the host 

INSTRUCTION

	push_wildcard.sh --push ecs-master-1.example.com ecs-1 sam
	push_wildcard.sh --push ecs-master-1.example.com ecs-1 cloudsale

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

	cert_dir=/opt/${cluster_name}/security/pki

	ssh -t ${host_name} sudo ls ${cert_dir} >> ${logfile} 2>&1
	ans=$?

	if [ ! ${ans} -eq 0 ]; then
		ssh -t ${host_name} sudo mkdir -p /opt/${cluster_name}/security/pki
	fi
}

function push_key() {

	cert_dir=/opt/${cluster_name}/security/pki
	key_file=${cert_name}.key

	if [ -f ${cert_dir}/${key_file} ]; then
		sudo chmod 666 ${cert_dir}/${key_file}
		sudo scp ${cert_dir}/${key_file} ${host_name}:/tmp/${key_file}
		ssh -t ${host_name} "sudo mv /tmp/${key_file} ${cert_dir}/${key_file}"
		ssh -t ${host_name} "sudo chmod 400 ${cert_dir}/${key_file}"
	fi 
}

function push_cert() {

	cert_dir=/opt/${cluster_name}/security/pki
	cert_file=${cert_name}.crt

	if [ -f ${cert_dir}/${key_file} ]; then
		sudo scp ${cert_dir}/${cert_file} ${host_name}:/tmp/${cert_file}
		ssh -t ${host_name} "sudo mv /tmp/${cert_file} ${cert_dir}/${cert_file}"
	fi 
}

function check_cert() {

	cert_dir=/opt/${cluster_name}/security/pki
	cert_file=${cert_name}.crt

	ssh -t ${host_name} ls ${cert_dir}/${cert_file} >> ${logfile} 2>&1
	ans=$?

	if [ ${ans} -eq 0 ]; then
		echo "Certificate files available on ${host_name}:"
		ssh -t ${host_name} ls -l /opt/${cluster_name}/security/pki
	else
		echo "ERROR: File transfered failed."
	fi
}


function run_option() {
# Case statement for options.

    case "${option}" in
        -h | --help)
            	get_help
            	;;
        -p |--push)
            	check_arg 4
		create_dir
		push_key
		push_cert
		check_cert
            	;;
        *)
            	usage
            	;;
    esac
}

function main() {

	# Run checks
	call_include
	check_sudo
	setup_log

	# Run command
	run_option

	# Review log file
	#echo "Review log file at ${logfile}"
}

#MAIN
main "$@"
exit 0
