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

# Title: manage_jssecacerts.sh
# Author: WKD
# Date: 17MAR22
# Purpose: Run commands to create the jssecacerts file. This file is
# used by Auto-TLS when deploying Cloudera Manager as the root CA. 
# Import the in_cluster truststore into the jssecacerts truststore.
# The jssecacerts truststore should then be distributed to all hosts.
# This is used as a work around for the yarn_kms issue.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLE
num_arg=$#
dir=${HOME}
option=$1
host=cmhost.example.com
host_file=${dir}/conf/listhosts.txt
work_dir=/usr/java/default/jre/lib/security
jssecacerts_password=BadPass@1
cm_truststore_pem=/var/lib/cloudera-scm-agent/agent-cert/cm-auto-in_cluster_ca_cert.pem
logfile=${dir}/log/$(basename $0).log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [option]"
	exit
}

function get_help() {
# Help page

cat << EOF
SYNOPSIS
	manage_jssecacerts.sh [OPTION]

DESCRIPTION
	Create and delete the jssecacerts file. This does not distribute the 
	file. Use the run_remote_file.sh tool to distribute to all hosts.

	-h, --help
		Help page
	-c, --create
		Creates jssecacerts.pem
	-d, --delete
		Delete all versions of the jssecacerts file
	-i, --import
		Import the in_custer truststore
	-l, --list
		List the directory for the jssecacerts
	-s, --show
		Show the contents of the jssecacerts
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

function create_jssecacerts() {
# Create the jssecacerts file.

	sudo cp ${work_dir}/cacerts ${work_dir}/jssecacerts
	sudo keytool -storepasswd -keystore ${work_dir}/jssecacerts -storepass changeit -new ${jssecacerts_password}
	sudo keytool -importkeystore -srckeystore ${work_dir}/jssecacerts -srcstorepass ${jssecacerts_password} -deststoretype PKCS12 -destkeystore ${work_dir}/jssecacerts.p12 -deststorepass ${jssecacerts_password}
	sudo openssl pkcs12 -in ${work_dir}/jssecacerts.p12 -passin pass:${jssecacerts_password} -out ${work_dir}/jssecacerts.pem
}

function delete_jssecacerts() {
# Describe function.

        echo -n "Confirm delete. "
        check_continue

	if [ -f "${work_dir}/jssecacerts" ]; then
		sudo rm ${work_dir}/jssecacerts ${work_dir}/jssecacerts.p12 ${work_dir}/jssecacerts.pem
	else
		echo "The jssecacerts does not exist"
	fi
}

function set_ssl() {
# Set the variables for ssl by pulling from the ssl-client.xml file.

    export ssl_client=/etc/hadoop/conf/ssl-client.xml
    export truststore_location=$(xmllint --xpath "//configuration/property[name='ssl.client.truststore.location']/value/text()" ${ssl_client})
    export truststore_password=$(xmllint --xpath "//configuration/property[name='ssl.client.truststore.password']/value/text()" ${ssl_client})

    export pem_location=/var/lib/cloudera-scm-agent/agent-cert/cm-auto-global_cacerts.pem
}

function import_jssecacerts() {
# Describe function.

	sudo keytool -import -keystore ${work_dir}/jssecacerts -storepass ${jssecacerts_password} -alias cmrootca-0 -file ${cm_truststore_pem} -noprompt
}

function list_dir() {

	ls ${work_dir}
}

function show_jssecacerts() {
# Describe function.

	sudo keytool -printcert -v -file ${work_dir}/jssecacerts.pem
}

 function run_option() {
# Case statement for options.

	case "${option}" in
		-h | --help)
			get_help
			;;
		-c | --create)
			check_arg 1	
			create_jssecacerts
			;;
		-d | --delete)
			check_arg 1	
			delete_jssecacerts
			;;
		-i | --import)
			check_arg 1	
			set_ssl
			import_jssecacerts
			;;
		-l | --list)
			check_arg 1
			list_dir
			;;
		-s | --show)
			check_arg 1
			show_jssecacerts
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

	# Run command
	run_option

	# Review log file
	#echo "Review log file at ${logfile}"
}

#MAIN
main "$@"
exit 0
