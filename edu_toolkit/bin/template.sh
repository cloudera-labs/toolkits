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

# Title: script_name.sh
# Author: WKD
# Date: 17MAR22
# Purpose: Write the purpose 

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLE
num_arg=$#
dir=${HOME}
host=cmhost.example.com
host_FILE=${dir}/conf/listhosts.txt
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
	script_name.sh [OPTION]

DESCRIPTION
	Detailed explaination. 

	-h, --help
		help page
	-j, --jdbc
		Inspect the jdbc connection.
	-m, --master
		Use the masters to run beeline.
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
# Description 
	echo "Hello"
}

function list_action() {
# Show the jdbc for a copy and paste.
	echo "Hello"
}

function run_option() {
# Case statement for options.

    case "${option}" in
        -h | --help)
            get_help
            ;;
        -j |--jdbc)
            check_arg 1
	    list_jdbc
            ;;
        -m | --master)
            check_arg 1	
	    run_master 
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
