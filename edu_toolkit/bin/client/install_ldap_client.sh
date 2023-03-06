#!/bin/sh

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

# Title: install_ldap_client.sh
# Author: WKD
# Date: 1MAR18
# Purpose: Script to install ldap software in support of LDAP client. 
# Script requires the input of the LDAP IPADDRESS address and the LDAP
# password. The script loads software, configures the connection, 
# and then runs tests to validate. 
# Note: This scripts is intended to be run on every node of the cluster

# DEBUG
#set -x
#set -eu
#set >> /root/setvar.txt

# VARIABLES
num_arg=$#
option=$1
dir=${HOME}
work_dir=${HOME}
logfile=${dir}/log/$(basename $0).log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [OPTION]" 1>&2
        exit 1
}

function get_help() {
# get help

cat << EOF
SYNOPSIS
	install_ldap_client.sh [OPTION]

DESCRIPTION
	Install the ldap client and test both openssl and ldapsearch.
	This script must be run on the local host.

	-h | --help
		Help page
	-i | --install
		Install LDAP 
	-t | --test
		Test the LDAP connection 
EOF
	exit
}

function check_sudo() {
# Testing for sudo access to root

        sudo ls /root > /dev/null
        if [ "$?" != 0 ]; then
                echo "ERROR: You must have sudo to root to run this script"
                usage
        fi
}

function check_arg() {
# Check arguments exits

        if [ ${num_arg} -ne "$1" ]; then
                usage
                exit 1 
        fi
}

function install_ldap() {
# Install openldap package

	sudo yum -y install openldap-clients ca-certificates
	sudo cp ${work_dir}/certs/security/ca.crt /etc/pki/ca-trust/source/anchors/hortonworks-net.crt
	sudo update-ca-trust force-enable
	sudo update-ca-trust extract
	sudo update-ca-trust check
}

function test_ssl() {
# test connection to AD using openssl client

	echo "Testing connection to LDAP using the openssl client"
	openssl s_client -connect ipa.example.com:636 </dev/null
}

function test_ldap() {
# test connection to AD using ldapsearch 
# when prompted for password, enter: BadPassW0rd!9

	echo "Testing ldapsearch using the ldap client"
	ldapsearch -x uid=allan_admin
}


function run_option() {
# Case statement for options

	case "${option}" in
		-h | --help)
			get_help
			;;
		-i | --install)
			check_arg 3
			check_ip
			install_ldap
			;;
		-t | --test)
			check_arg 1
			test_ssl
			test_ldap
			;;
		*)
			usage
			;;
	esac
}

function main() {
	# Run checks
	check_sudo

	# Run option
	run_option

	# Review log file
	#echo "Review log file at ${logfile}"
}

# MAIN
main "$@"
exit
