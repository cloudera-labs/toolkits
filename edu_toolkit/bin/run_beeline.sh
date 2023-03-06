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
num_arg=$#
dir=${HOME}
host=cmhost.example.com
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
	run_beeline.sh [OPTION]

DESCRIPTION
	Run beeline from various connections

	-h, --help
		Help page
	-m, --master
		Use the masters to run beeline.
	-s, --show
		Show the code.
	-z, --zookeeper
		Use the zookeepers to run beeline.
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

function run_master() {
# Start up beeline in classroom environment with TLS and Kerberos.

	beeline -u 'jdbc:hive2://master-2.example.com:10000/default;ssl=true;sslTrustStore=/var/lib/cloudera-scm-agent/agent-cert/cm-auto-in_cluster_truststore.jks;principal=hive/_host@EXAMPLE.COM'
}

function show_jdbc() {
# Show the jdbc for a copy and paste.

	echo --------Cut and paste-------

	echo "jdbc:hive2://master-2.example.com:10000/default;ssl=true;sslTrustStore=/var/lib/cloudera-scm-agent/agent-cert/cm-auto-in_cluster_truststore.jks;principal=hive/_host@EXAMPLE.COM"

	echo "beeline -u 'jdbc:hive2://master-1.example.com:2181,master-2.example.com:2181,master-3.example.com:2181/default;serviceDiscoverMode=zookeeper;zooKeeperNamespace=hiveserver2;ssl=true;sslTrustStore=/var/lib/cloudera-scm-agent/agent-cert/cm-auto-in_cluster_truststore.jks;principal=hive/_host@EXAMPLE.COM'"

	echo ------------------------------
}

function run_zookeeper() {
# Start up beeline in classroom environment with TLS and Kerberos.

	beeline -u 'jdbc:hive2://master-1.example.com:2181,master-2.example.com:2181,master-3.example.com:2181/default;serviceDiscoverMode=zookeeper;zooKeeperNamespace=hiveserver2;ssl=true;sslTrustStore=/var/lib/cloudera-scm-agent/agent-cert/cm-auto-in_cluster_truststore.jks;principal=hive/_host@EXAMPLE.COM'
}

function run_option() {
# Case statement for options.

	case "${option}" in
		-h | --help)
			get_help
			;;
		-m | --master)
			check_arg 1	
			run_master 
			;;
		-s |--show)
			check_arg 1
			show_jdbc
			;;
		-z | --zookeeper)
			check_arg 1	
			run_zookeeper
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
