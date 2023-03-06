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

# Title: manage_auto-tls.sh
# Author: WKD
# Date: 21FEB23 
# Purpose: Manage auto-tls command line for the purpose of assigning
# Cloudera Manager as a CA on a cluster with hosts and services installed.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLE
num_arg=$#
dir=${HOME}
host=cmhost.example.com
certmgr_dir=/var/lib/cloudera-scm-server/certmanager
ca_host=ipa.example.com
cm_host=cmhost.example.com
option=$1
logfile=${dir}/log/$(basename $0).log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [OPTION]"
        exit
}

function get_help() {
# Help page

cat << EOF
SYNOPSIS
	manage_auto-tls.sh [OPTION]

DESCRIPTION
	Run commands to assign Cloudera Manager as an intermediate CA. 

	-h, --help
		Help page.
	-b, --backup
		Backup the certificate manager directory.
	-c, --csr
		Create the CM csr file.
	-d, --delete
		Delete the certifcate manager directory
	-i, --init
		Initialze Auto-TLS on cmhost.
	-l, --list
		List the certificate manager directory
	-m, --move
		Move the trust chain into the /etc/pki/cm directory.
	-o, --own
		Change the ownership of the cmca directory to cloudera-scm.
	-r, --restart
		Restart Cloudera Manager.
	-s, --scp
		Copy the cm_ca.csr file to the CA host.

INSTRUCTIONS

	1. Save the CSR certificate.
		manage_auto-tls.sh --csr
	2. Copy the cm_ca.csr file from /tmp/cm_ca.csr to the CA host /tmp.
		manage_auto-tls.sh --scp
	3. On the CA host use recommended practice to sign the csr.
	4. Create a trust chain by adding the signed CM certificate to the CA certificate.
	   The files should be cm_ca.crt and cm_ca_chain.crt.
	5. Copy both files back to the cm host /tmp.
	6. Move the files into the certificate manager directory.
		manage_auto-tls.sh --move
	7. Change the ownership to cloudera-scm.
		manage_auto-tls.sh --own
	8. Create backup of the certificate manager directory
		manage_auto-tls.sh --backup
	9. Initialize Auto-TLS.
		manage_auto-tls.sh --init
	10. When successful restart Cloudera Manager. 
		manage_auto-tls.sh --restart

TROUBLESHOOTING
	
	The log can be tailed at /var/log/cloudera-scm-agent/certmanager.log

	If required to repeat the process then delete the certification manager directory 
	and restore from the backup before proceeding.

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

function run_backup() {
# Run the backup of CMCA directory. 

	if [ ! -d ${certmgr_dir} ]; then
		sudo cp -r ${certmgr_dir} /var/lib/cloudera-scm-server/certmanager.bak
	else
		echo "NOTE The backup directory exists."
	fi
}

function run_csr() {
# Run the save csr command.

	sudo -E /opt/cloudera/cm-agent/bin/certmanager --location ${certmgr_dir} setup --configure-services --override ca_dn=CN=${ca_host} --stop-at-csr

	sudo cp ${certmgr_dir}/CMCA/private/ca_csr.pem /tmp/cm_ca.csr
	ls /tmp/cm_ca.csr
}

function run_delete() {

	sudo rm -r ${certmgr_dir}
}

function run_init() {

	curl -i -v -u "training:BadPass@1" -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' -d '{ 
	"location" : "/var/lib/cloudera-scm-server/certmanager/CMCA", 
	"additionalArguments" : ["--override", "ca_dn=CN=ipa.example.com", 
"--signed-ca-cert=/etc/pki/cm/private/cm_ca_chain.crt"], 
	"configureAllServices" : "true", 
	"sshPort" : 22, 
	"userName" : "training", 
	"password" : "BadPass@1" 
}' "http://${cm_host}:7180/api/v41/cm/commands/generateCmca"

}

function list_dir() {
# List the certification manager directory

	sudo ls ${certmgr_dir}
	sudo ls ${certmgr_dir}/CMCA
	sudo ls ${certmgr_dir}/CMCA/private

}

function run_move() {

	sudo mkdir -p /etc/pki/cm
	sudo mv /tmp/cm_ca.crt /tmp/cm_ca_chain.crt /etc/pki/cm
}

function run_own() {
# Change ownership of the certification manager directory.

	sudo chown -R cloudera-scm:cloudera-scm ${certmgr_dir}
	sudo ls -l ${certmgr_dir}/CMCA
}

function run_restart() {

	sudo systemctl restart cloudera-scm-server
}

function run_scp() {

	scp /tmp/cm_ca.csr ${ca_host}:/tmp/
}
		
function run_option() {
# Case statement for options.

	case "${option}" in
		-h | --help)
			get_help
			;;
		-b | --backup)
			check_arg 1	
			run_backup 
			;;
		-c |--csr)
			check_arg 1
			run_csr
			;;
		-d | --delete)
			check_arg 1
			run_delete
			;;
		-i | --init)
			check_arg 1	
			run_init
			;;
		-l | --list)
			check_arg 1
			list_dir
			;;
		-m | --move)
			check_arg 1
			run_move
			;;
		-o | --own)
			check_arg 1
			run_own
			;;
		-r | --restart)
			check_arg 1
			run_restart
			;;
		-s | --scp)
			check_arg 1
			run_scp
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
