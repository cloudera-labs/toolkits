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

# Title: manage_ssh_key.sh
# Author: WKD 
# Date: 180318 
# Purpose: This creates the ssh keys to be used by Cloudera Manager 
# for the Edu cluster. These keys will have to be put into place manually.

# DEBUG
#set -x
#set -eu
#set >> /root/setvar.txt

# CHANGES
# RFC-1274 Script Maintenance

# VARIABLES
num_arg=$#
option=$1
dir=${HOME}
key_dir=${dir}/key
ssh_dir=${dir}/.ssh
#ssh_dir=${dir}/test
logfile=${dir}/log/$(basename $0).log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [OPTION]" 
        exit 1
}

function call_include() {
# Test for script and run functions

        if [ -f ${dir}/bin/include.sh ]; then
                source ${dir}/bin/include.sh
        else
                echo "ERROR: The file ${dir}/bin/functions not found."
                echo "This required file provides supporting functions."
		exit 1
        fi
}

function get_help() {
# get help

cat << EOF
SYNOPSIS
	manage_ssh_key.sh [OPTION]

DESCRIPTION
	This tool creates a directory, key, for the keypairs.
	The keys can be copied into .ssh and give the correct permisions.
	It is good practice to then delete the key directory.
	CAUTION: Deleting keys in .ssh can result in major rework.
	For this reason the keys in .ssh must be deleted manually.

	-h, --help
		Help page
	-d, --delete
		Delete the key directory and the keys 
	-k, --key
        	Create the key directory and the keypair
	-s, --ssh
		Copy the keypairs to the .ssh directory
EOF
	exit
}

function create_keypair() {
# Create a ssh private and public key, retain a copy in the certs directory.

	if [ ! -d ${key_dir} ]; then
		mkdir -p ${key_dir}
	fi

	# Create keys
	ssh-keygen -b 2048 -t rsa -f ${key_dir}/keypair -q -N ""
}

function create_ssh() {
	# Build keys
	cp ${key_dir}/keypair ${ssh_dir}/id_rsa 
	cp ${key_dir}/keypair.pub ${ssh_dir}/authorized_keys

	# Set permissions	
	chmod 400 ${ssh_dir}/id_rsa
	chmod 600 ${ssh_dir}/authorized_keys
}

function delete_cert() {
# Remove the certification key directory

		if [ -d ${key_dir} ]; then
			echo -n "The ${key_dir} directory exists. "
			check_continue
        	rm -r -f ${key_dir}
		fi
}

function run_option() {
# Case statement for options.

	case "${option}" in
		-h | --help)
			get_help
			;;
		-d | --delete)
			check_arg 1
			delete_cert
			;;
		-k | --key)
			check_arg 1
			create_keypair
			;;
		-s | --ssh)
			create_ssh
			;;
		*)
			usage
			;;
	esac
}


function main() {

	# Source functions
	call_include

	# Run option
	run_option

	# Review log file
	#echo "Review log file at ${logfile}"
}

#MAIN
main "$@"
exit 0
