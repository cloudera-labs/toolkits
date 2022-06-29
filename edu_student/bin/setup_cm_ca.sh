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

# Title: setup_cm_ca.sh
# Author: WKD
# Date: 30MAY22
# Purpose: Run the commands to setup Cloudera Manager as an intermediate CA.
# This command must be run on the cmhost. The CA root is on an IPA server.
# The function to sign the Cloudera Manager certificate signing request
# uses IPA commands.  

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
NUMARGS=$#
DIR=${HOME}
HOST=cmhost.example.com
HOST_FILE=${DIR}/conf/listhosts.txt
OPTION=$1
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${HOME}/log/setup_cm_ca.log

# FUNCTIONS
function usage() {
    echo "Usage: $(basename $0) [run|cleanup]" 
    exit
}

function call_include() {
# Test for include script.

        if [ -f ${DIR}/bin/include.sh ]; then
                source ${DIR}/bin/include.sh
        else
                echo "ERROR: The file ${DIR}/bin/include.sh not found."
                echo "This required file provides supporting functions."
        exit 1
        fi
}

function cleanup() {
# Remove the certmanager directory and any files.

	rm -r -f /var/lib/cloudera-scm-server/certmanager
}

function setup_certmgr() {
# Setup the certificate manager directory.

	sudo mkdir -p /var/lib/cloudera-scm-server/certmanager
	sudo chown -R cloudera-scm:cloudera-scm /var/lib/cloudera-scm-server/certmanager
}

function init_tls() {
# Create the private key and the certificate signing request in the
# certificate manager directory.

	sudo sh -c "export JAVA_HOME=/usr/java/default; /opt/cloudera/cm-agent/bin/certmanager --location /var/lib/cloudera-scm-server/certmanager  setup --configure-services --override ca_dn=CN=cmhost.example.com --stop-at-csr"
}

function kinit_root() {
# Initiate a TGT for root. This is required to run the IPA command.
	sudo sh -c "kinit -kt /etc/krb5.keytab host/cmhost.example.com"
}

function sign_csr() {
# Use IPA command to sign the certificate signing request.
	sudo sh -c "ipa cert-request /var/lib/cloudera-scm-server/certmanager/CMCA/private/ca_csr.pem --principal=host/cmhost.example.com --chain --certificate-out=/var/lib/cloudera-scm-server/certmanager/CMCA/private/ca_crt.pem"
}

function generate_cmca() {
# Use the REST API to run Auto-TLS to generate all keystores and PEM files
# on all hosts.

	curl -i -v -u training -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' -d '{
"location": "/var/lib/cloudera-scm-server/certmanager",
"additionalArguments" : ["--override", "ca_dn=CN=cmhost.example.com", 
"--signed-ca-cert=/var/lib/cloudera-scm-server/certmanager/CMCA/private/ca_crt.pem"],
"configureAllServices" : "true",
"sshPort" : 22,
"userName" : "training",
"password" : "BadPass@1"
}' "http://${HOST}:7180/api/v41/cm/commands/generateCmca"
}

function run_option() {
# Case statement for options.

    case "${OPTION}" in
        -h | --help)
			usage
			;;
		cleanup)
			check_arg 1
			cleanup
			;;
		run)
			check_arg 1
			setup_certmgr
			init_tls
			kinit_root
			sign_csr
			generate_cmca
			;;
        *)
			usage
        	;;
    esac
}

# MAIN
# Run checks
call_include
check_tgt
check_sudo

# Run command
run_option
