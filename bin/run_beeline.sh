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

# Title: run_beeline.sh
# Author: WKD
# Date: 17MAR22
# Purpose: Run the beeline command in a classroom environment with
# TLS and Kerberos. Show the jdbc string for a cut and paste.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLE
NUMARGS=$#
DIR=${HOME}
HOST=cmhost.example.com
HOST_FILE=${DIR}/conf/listhosts.txt
OPTION=$1
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${DIR}/log/run_beeline.log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [run|show]"
        exit
}

function call_include() {
# Test for include script.

        if [ -f ${DIR}/bin/include.sh ]; then
                source ${DIR}/bin//include.sh
        else
                echo "ERROR: The file ${DIR}/bin/include.sh not found."
                echo "This required file provides supporting functions."
                exit 1
        fi
}

function run_beeline() {
# Start up beeline in classroom environment with TLS and Kerberos.

	beeline -u 'jdbc:hive2://master-2.example.com:10000/default;ssl=true;sslTrustStore=/var/lib/cloudera-scm-agent/agent-cert/cm-auto-in_cluster_truststore.jks;principal=hive/_HOST@EXAMPLE.COM'
}

function show_jdbc() {
# Show the jdbc for a copy and paste.

	echo --------Cut and paste-------
	echo "jdbc:hive2://master-2.example.com:10000/default;ssl=true;sslTrustStore=/var/lib/cloudera-scm-agent/agent-cert/cm-auto-in_cluster_truststore.jks;principal=hive/_HOST@EXAMPLE.COM"
	echo ------------------------------
}

function run_option() {
# Case statement for options.

    case "${OPTION}" in
        -h | --help)
            usage
            ;;
        run)
            check_arg 1	
	    run_beeline 
            ;;
        show)
            check_arg 1
	    show_jdbc
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
