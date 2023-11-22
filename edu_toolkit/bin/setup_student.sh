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

# Title: setup_student.sh
# Author: WKD
# Date: 17MAR22
# Purpose: Setup the training user with directories and configuration files. 

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLE
num_arg=$#
dir=${HOME}
option=$1
#content=${dir}/training_materials/security
content=${dir}/src/toolkits/edu_toolkit
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
        setup_student.sh [OPTION]

DESCRIPTION
        Setup the student for the user training

        -h, --help
                Help page
        -d, --delete
                Delete the student directories 
        -s, --setup
                Setup the student directories
EOF
        exit
}

function check_arg() {
# Check if arguments exits

        if [ ${num_arg} -ne "$1" ]; then
                usage
        fi
}

function check_sudo() {
# Testing for sudo access to root

        sudo ls /root > /dev/null 2>&1
        result=$?
        if [ ${result} -ne 0 ]; then
                echo "ERROR: You must have sudo to root to run this script"
                usage
        fi
}

function make_dir() {

	if [ ! -d $dir/bin ]; then
		for directory in bin conf data notebook tutorial; do
			mkdir $directory
		done
	fi
}

function copy_dir() {
# Describe function.

	if [ -d ${content} ] ; then
		sudo cp -R ${content}/* ${HOME}/
		cd ${HOME}
		sudo chown -R training:training bin conf data ddl notebook tutorial
	else
		echo "Configure the content directory in the script"
		echo "Current content directory is ${content}"
	fi
}

function setup_conf() {
# Setup configuration files, escape alias for cp -i
	
#	alias cp='cp -f'
	if [ -f ${HOME}/conf/bashrc ]; then
		cp ${HOME}/conf/bash_profile ${HOME}/.bash_profile
		cp ${HOME}/conf/bashrc ${HOME}/.bashrc
	else
		echo "ERROR: The configuration file for bashrc is missing"
	fi
}

function delete_dir() {
# delete the student directories for training

	cd ${HOME}
	rm -r -f bin conf data ddl notebook tutorial
}

function clean_dir() {
# Clean up working directory

	if [ -d ${HOME}/Music ]; then	
		rmdir ${HOME}/Music
		rmdir ${HOME}/Pictures
		rmdir ${HOME}/Videos
	fi
}

function list_dir() {
# list the directory

	ls ${HOME}
}

function run_option() {
# Case statement for options.

        case "${option}" in
                -h | --help)
                        get_help
                        ;;
                -d | --delete)
                        check_arg 1
                       	delete_dir 
                        ;;
                -s |--setup)
                        check_arg 1
			make_dir
			copy_dir
			setup_conf
			clean_dir
			list_dir
                        ;;
                *)
                        usage
                        ;;
        esac
}

function main() {

        # Run checks
	check_sudo

        # Run command
        run_option

	# Review log file
	#echo "Review log file at ${logfile}"
}

#MAIN
main "$@"
exit 0
