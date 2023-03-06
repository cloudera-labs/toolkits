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

# Title: checkpoint_hdfs.sh
# Author: WKD
# Date: 1MAR18
# Purpose: This script check_points the NameNode. If the cluster has
# been offline for 24 hours a check point alert will be raised. It 
# will correct in time. Run this script as a CDP admin with superuser
# status to HDFS. The CDP admin requires a Kerberos TGT.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLE
num_arg=$#
option=$1
dir=${HOME}
master_host=master-1.example.com
sudo_user="training"
priv_key="${dir}/.ssh/admincourse.pem"
logfile=${dir}/log/$(basename $0).log

# FUNCTIONS
function usage() {

        echo "Usage: $(basename $0) [OPTION]"
        exit 
}

function call_include() {
# Test for script and run functions

        if [ -f ${dir}/bin/include.sh ]; then
                source ${dir}/bin//include.sh
        else
                echo "ERROR: The file ${dir}/bin/include.sh not found."
                echo "This required file provides supporting functions."
		exit 1
        fi
}

function get_help() {
# get help

cat << EOF
SYNOPSIS
	build_cdp_host.sh [OPTION]

DESCRIPTION
	Use this tool to checkpoint HDFS. This tool supports both
	a Kerberos environment and a Sudo environment.

	-h, --help)
		Help page
	-k, --kerberos)
		Checkpoint with Kerberos
	-l, --list)
		List the hdfs keytab 
	-s, --sudo)
		Checkpoint with sudo, for hosts without Kerberos 
EOF
	exit
}

function klist_nn() {
# Pull the location of the nn keytab file and then kinit for hdfs

    ssh -i ${priv_key} -o StrictHostKeyChecking=no  ${sudo_user}@${master_host} "
		sudo /opt/cloudera/cm-agent/bin/supervisorctl -c /var/run/cloudera-scm-agent/supervisor/supervisord.conf status | grep NAMENODE| awk '{ print \$1 }' > /tmp/namenode.txt
		node=\$(cat /tmp/namenode.txt)
		sudo -u hdfs klist -ket /var/run/cloudera-scm-agent/process/\${node}/hdfs.keytab"
}

function checkpoint_kerberos() {
# Pull the location of the nn keytab file and then kinit for hdfs

    ssh -i ${priv_key} -o StrictHostKeyChecking=no  ${sudo_user}@${master_host} "
		sudo /opt/cloudera/cm-agent/bin/supervisorctl -c /var/run/cloudera-scm-agent/supervisor/supervisord.conf status | grep NAMENODE| awk '{ print \$1 }' > /tmp/namenode.txt
		node=\$(cat /tmp/namenode.txt)
		sudo -u hdfs kinit -kt /var/run/cloudera-scm-agent/process/\${node}/hdfs.keytab hdfs/master-1.example.com@EXAMPLE.COM
		sudo -u hdfs hdfs dfsadmin -rollEdits
		sudo -u hdfs hdfs dfsadmin -safemode enter
		sudo -u hdfs hdfs dfsadmin -saveNamespace
		sudo -u hdfs hdfs dfsadmin -safemode leave"
}

function checkpoint_sudo() {
# Place NN in safemode and the merge editlogs into fsimage

	 sudo -u hdfs hdfs dfsadmin -rollEdits
	 sudo -u hdfs hdfs dfsadmin -safemode enter
	 sudo -u hdfs hdfs dfsadmin -saveNamespace
	 sudo -u hdfs hdfs dfsadmin -safemode leave
}

function run_option() {
# Case statement for options.

    case "${option}" in
        -h | --help)
            get_help
            ;;
        -k | --kerberos)
            check_arg 1
            checkpoint_kerberos
            ;;
        -l | --list)
            check_arg 1
            klist_nn
            ;;
        -s | --sudo)
            check_arg 1
			checkpoint_sudo
			;;
        *)
            usage
            ;;
    esac
}

function main() {
	# Source Functions
	call_include

	# Run checks
	check_sudo

	# Run option
	run_option

	# Review log file
	#echo "Review log file at ${logfile}"
}

# MAIN
main "$@"
exit 0
