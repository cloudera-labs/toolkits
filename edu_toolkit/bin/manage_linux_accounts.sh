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

# Title: manage_linux_accounts.sh
# Author: WKD
# Date: 1MAR18
# Purpose: Create or delete Linux power users in support of HDP. This 
# script will create and delete users for every node in the node list.

# DEBUG
# set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
num_arg=$#
dir=${HOME}
option=$1
hostS=${dir}/conf/list_host.txt
group_file=${dir}/conf/list_group.txt
user=${dir}/conf/list_user.txt
logfile=${dir}/log/$(basename $0).log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [OPTION]"
        exit 1
}

function get_help() {
# Help page

cat << EOF
SYNOPSIS
	manage_linux_accounts.sh [OPTION]

DESCRIPTION
	Manage Linux accounts.

	-h, --help
		Help page
	-a, addusers
		Add users to /etc/passwd file on all hosts.
	-d, --delusers
		Delete users from /etc/passwd file on all hosts.
	-g, --addgrps
		Add groups to /etc/groups file on all hosts.
	-k, --keys
		Create .ssh and add private and public key.
	-r, --rmgrps 
		Delete groups from /etc/group file on all hosts.
EOF
	exit
}

function call_include() {
# Test for script and run functions

        if [ -f ${dir}/bin/include.sh ]; then
                source ${dir}/bin/include.sh
        else
		echo "Include file not found"
        fi
}

function checkGroups() {
# Check groups exist before adding users

	grep biz /etc/group > /dev/null 2>&1 
	FLAG=$(echo $?)

	if [ ${FLAG} -eq 1 ]; then
		echo "You must add groups first"
		usage
	fi
}

function add_group() {
# Add groups contained in the groups file       

        for host in $(cat ${host}); do
                echo "Adding Linux groups on ${host}" | tee -a "${logfile}"
                while read -r NEWGROUP; do
                ssh -tt ${host} "sudo groupadd ${NEWGROUP}" < /dev/null >> ${logfile} 2>&1
                done < ${group_file}
        done
}

function add_user() {
# use this CLI for standard users

	#echo -n "Create user accounts?"
	#checkcontinue

	for host in $(cat ${host}); do
		echo "Creating user accounts on ${host}"
		while IFS=: read -r NEWUSER NEWGROUP; do
			ssh -tt ${host} "sudo useradd -d /home/${NEWUSER} -g ${NEWGROUP} -m ${NEWUSER}" < /dev/null  >> ${logfile} 2>&1
		done < ${user}
	done
}

function add_key() {
# Add the authorized_keys file

	for host in $(cat ${host}); do
		echo "Adding authorized keys on ${host}"
		while IFS=: read -r NEWUSER NEWGROUP; do
			ssh -tt ${host} "sudo mkdir -p /home/${NEWUSER}/.ssh" < /dev/null  >> ${logfile} 2>&1
			ssh -tt ${host} "sudo cp ${HOME}/.ssh/id_rsa /home/${NEWUSER}/.ssh/id_rsa" < /dev/null  >> ${logfile} 2>&1
			ssh -tt ${host} "sudo cp ${HOME}/.ssh/id_rsa.pub /home/${NEWUSER}/.ssh/id_rsa.pub" < /dev/null  >> ${logfile} 2>&1
			ssh -tt ${host} "sudo cp ${HOME}/.ssh/authorized_keys /home/${NEWUSER}/.ssh/authorized_keys" < /dev/null  >> ${logfile} 2>&1
			ssh -tt ${host} "sudo cp ${HOME}/.bash_profile /home/${NEWUSER}/.bash_profile" < /dev/null  >> ${logfile} 2>&1
			ssh -tt ${host} "sudo cp ${HOME}/.bashrc /home/${NEWUSER}/.bashrc" < /dev/null  >> ${logfile} 2>&1
			ssh -tt ${host} "sudo chown -R ${NEWUSER}:${NEWGROUP} /home/${NEWUSER}" < /dev/null  >> ${logfile} 2>&1
		done < ${user}
	done
}

function delete_group() {
# Delete groups contained in the groups file    

        for host in $(cat ${host}); do
                echo "Deleting Linux groups on ${host}" | tee -a "${logfile}"
                while read -r NEWGROUP; do
                        ssh -tt ${host} "sudo groupdel ${NEWGROUP}" < /dev/null >> ${logfile} 2>&1
                done < ${group_file}
        done
}

function delete_user() {
	#echo -n "Delete user accounts?"
	#checkcontinue
	
	for host in $(cat ${host}); do
		echo "Deleting user accounts on ${host}"
		while IFS=: read -r NEWUSER NEWGROUP; do
			ssh -tt ${host} "sudo userdel -r ${NEWUSER}" < /dev/null >> ${logfile} 2>&1
			ssh -tt ${host} "sudo rm -r /home/${NEWUSER}" < /dev/null >> ${logfile} 2>&1

		done < ${user}
	done
}

function run_option() {
# Case statement for add or delete Linux users

	case "${option}" in
                -h | --help)
                        get_help
			;;
                -a | --addusers)
			check_arg 1
			checkGroups
			add_user
			;;
                -d |  --delusers)
			check_arg 1
			delete_user
			;;
		-g |  --addgrps)
			check_arg 1
			add_group
			;;
		-k |  --keys)
			check_arg 1
			add_key 
			;;
		-r |  --rmgrps)
			check_arg 1
                        delete_group
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
	check_file ${user}
	check_file ${hosts}

	# Run option
	run_option

	# Review log file
	#echo "Review log file at ${logfile}"
}

#MAIN
main "$@"
exit 0
