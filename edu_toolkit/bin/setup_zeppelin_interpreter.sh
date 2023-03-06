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

# Title: template.sh
# Author: WKD
# Date: 06JUN22
# Purpose: Install Zeppelin interpreters for Shell, JDBC, and Livy. 

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLE
num_arg=$#
dir=${HOME}
json_file=${dir}/conf/interpreter.json
host=edge.example.com
host_list=${dir}/conf/list_host.txt
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
        setup_zeppelin_interpreter.sh [OPTION]

DESCRIPTION
       	Display the content of the Zeppelin interpreter.json_file to view 
	the configurations for the jdbc, livy, and sh interpreter. Run 
	configure to copy this file into place. Restart Zeppelin and
	test. In the notebook/zeppelin directory there is a notebook
	purposelly designed to test all three intrepreters. 

        -h, --help
                Help page
	-c --config
		Config the zeppelin interpreter
        -d, --display
               	Display the contents of the interpreter json 
	-k, --keytab
		Install the keytab

INSTRUCTIONS

	1. Display the content of the json_file.
		setup_zeppelin_interpreter.sh --display
	2. Create a static keytab for the zeppelin interpreters.
		setup_zeppelin_interpreter.sh --keytab 
	3. Configure the Zeppelin interpreters.
		setup_zeppelin_interpreter.sh --config 
	4. From Cloudera Manager Home restart Zeppelin
		Cloudera Manager > Zeppelin > Restart
	5. Login and validate the intepreters for sh, jdbc, and livy.
EOF
        exit
}

function call_include() {
# Test for include script

        if [ -f ${dir}/bin/include.sh ]; then
                source ${dir}/bin//include.sh
        else
                echo "ERROR: The file ${dir}/bin/include.sh not found."
                echo "This required file provides supporting functions."
                exit 1
        fi
}

function display_file() {
# Display the content of the interpreter.json_file
	
	cat ${json_file}
	echo
}

function setup_keytab() {
# Create a static keytab for zeppelin

	ssh -tt ${host} "sudo mkdir -p /etc/security/keytabs" >> ${logfile} 2>&1
	ssh -tt ${host} "sudo rm /etc/security/keytabs/zeppelin.keytab" >> $${logfile} 2>&1

	export key_dir=$(ssh edge.example.com sudo ls -Art /var/run/cloudera-scm-agent/process/ | grep -i zeppelin | tail -n 1)
	echo "The keytab is located in $key_dir" >> ${logfile} 2>&1

	ssh -tt ${host} "sudo cp /var/run/cloudera-scm-agent/process/$key_dir/zeppelin.keytab /etc/security/keytabs/zeppelin.keytab" >> ${logfile} 2>&1
	ssh -tt ${host} "sudo chown zeppelin:zeppelin /etc/security/keytabs/zeppelin.keytab" >> ${logfile} 2>&1
}

function install_shell_jar() {
# Install the jar files for the shell interpreter

	shell_jar=zeppelin-shell-0.8.2.7.1.7.0-551.jar

	ssh -tt ${host} "sudo /opt/cloudera/parcels/CDH/lib/zeppelin/bin/install-interpreter.sh --name shell --artifact /opt/cloudera/parcels/CDH/zeppelin/interprester/sh/${shell_jar}" >> ${logfile} 2>&1
	result=$?
	if [ ${result} -eq 0 ]; then
		echo "Install ${shell_jar} onto ${host}" | tee -a ${logfile}
	else
		echo "ERROR: Failed to install ${shell_jar} onto ${host}" | tee -a ${logfile}
    fi
}

function push_file() {
# Push a file into remote node.

    output=/tmp/interpreter.json

    check_file ${json_file}

	scp -r ${json_file} ${host}:${output} >> ${logfile} 2>&1
	result=$?
	if [ ${result} -eq 0 ]; then
		echo "Push ${json_file} to ${host}" | tee -a ${logfile}
	else        
		echo "ERROR: Failed to push ${json_file} to ${host}" | tee -a ${logfile}
	fi
}

function move_file() {
# Move a file into remote node. This is excuted as root.
# The file will have root ownership.

    json_file=/tmp/interpreter.json
    output=/var/lib/zeppelin/conf/interpreter.json

	ssh -tt ${host} "sudo mv ${json_file} ${output}"  >> ${logfile} 2>&1
	result=$?
	if [ ${result} -eq 0 ]; then
		echo "Moved ${json_file} on ${host} to location" | tee -a ${logfile}
		echo "Use Cloudera Manager to restart Zeppelin"
	else
		echo "ERROR: Failed to move ${json_file}" | tee -a ${logfile}
	fi
}

function run_option() {
# Case statement for options.

	case "${option}" in
		-h | --help)
			get_help
			;;
		-c | --config)
			check_arg 1	
			install_shell_jar
			push_file
			move_file		
			;;
		-d | --display)
			check_arg 1
			display_file
			;;
		-k | --keytab)
			check_arg 1
			setup_keytab
			;;
		*)
			usage
			;;
	esac
}

function main () {

	# Run checks
	call_include
	check_sudo

	# Run command
	setup_log
	run_option

	# Review log file
	#echo "Review log file at ${logfile}"
}

#MAIN
main "$@"
exit 0
