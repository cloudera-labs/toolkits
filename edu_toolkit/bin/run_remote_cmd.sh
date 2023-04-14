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

# Title: run_remote_cmd.sh
# Author: WKD
# Date: 210521 
# Purpose: Multipurpose script for basic admin functions.
# connect: Validate connect with ssh"
# reboot: Reboot all systems in host list"
# update: Run yum update all on all host in host list"
# cleanlog: Glean CDP logs in the /var/log directories" 
#  Check the applist.txt file for directories"

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
num_arg=$#
option=$1
input=$2
dir=${HOME}
host=${dir}/conf/list_host.txt
apps_list=${dir}/conf/list_app.txt
logfile=${dir}/log/$(basename $0).log

# FUNCTIONS
function usage() {
	echo "Usage: $(basename $0) [OPTION]" 
	exit
}

function get_help() {
# Instructions

cat << EOF
SYNOPSIS

	Usage: $(basename $0) [OPTION] 

DESCRIPTION
	This tool runs a number of useful utilities on a list
	of remote hosts.

	-h, --help
		Help page
	-c, --cmd <"command">
		Run a remote command with ssh
	-d, --deletelog 
		Delete CDP logs in the /var/log directories
	-r, --reboot
		Reboot all systems in host list
	-s, --ssh
		Validate connect with ssh
	-u, --update
		Run yum update all on all hosts in host list

EXAMPLES
	$ cat /home/user/conf/list_host.txt

	$ run_remote_node.sh -c "sudo mkdir /var/data"

	$ run_remote_node.sh -d
EOF
	exit 
}

function call_include() {
# Test for script and run functions

        if [ -f ${dir}/bin/include.sh ]; then
                source ${dir}/bin/include.sh
        else
                echo "ERROR: The file ${dir}/bin/include.sh not found."
                echo "This required file provides supporting functions."
		exit 1
        fi
}

function connect_host() {
# Rename the host name of the node

        echo "Answer 'yes' if asked to remote connect"

        for host in $(cat ${host}); do
                ssh ${host} echo "Testing" > /dev/null 2>&1
                if [ $? = "0" ]; then
                        echo "Connected to ${host}"
                else
                        echo "Failed to connect to ${host}"
                fi
        done
}

function delete_log() {
# Run a script clean out logs on all nodes

        for host in $(cat ${host}); do
    		while read -r APP; do
                        ssh -tt ${host} "sudo rm -r /var/log/${APP}/*" < /dev/null >> ${logfile} 2>&1
                done < ${apps_list}
                echo "Cleaned all logs on ${host}" | tee -a ${logfile}
        done
}

function reboot_host() {
# Run a script on the remote nodes

        for host in $(cat ${host}); do
                echo "Reboot ${host}" | tee -a ${logfile}
                ssh -tt ${host} "sudo reboot" >> ${logfile} 2>&1
        done
}

function run_cmd() {
# Run a script on the remote nodes

        for host in $(cat ${host}); do
                echo "Run a remote command on ${host}" | tee -a ${logfile}
                ssh -tt ${host} "${input}" >> ${logfile} 2>&1
        done
}

function update_host() {
# Run a script on the remote nodes

        for host in $(cat ${host}); do
                ssh -tt ${host} "sudo yum -y update" >> ${logfile} 2>&1
                echo "Run yum update on ${host}" | tee -a ${logfile}
        done
}

function run_option() {
# Case statement for options

	case "${option}" in
		-h | --help)
			get_help
			;;
  		-c | --cmd)
			check_arg 2
			run_cmd
			;;
		-d | --deletelog)
			check_arg 1
			delete_log
			;;
		-r | --reboot)
			check_arg 1
			reboot_host
			;;
		-s | --ssh)
			check_arg 1
			connect_host
			;;
		-u | --update)
			check_arg 1
			update_host
			;;
		*)
			usage
			;;
	esac
}

function main() {

	# Source functions
	call_include

	# Run checks
	check_sudo

	# Run setups
	setup_log ${logfile}

	# Run option
	run_option

	# Review log file
	echo "Review log file at ${logfile}"
}

#MAIN
main "$@"
exit 0
