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

# Title: setup_kubectl.sh
# Author: WKD
# Date: 06DEC22
# Purpose: Setup the Kubenetes config file to allow use of kubectl. 
# Generates an external_kubeconfig file under current user's home directory. 
# This kubeconfig can be used externally to access the RKE cluster.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLE
numargs=$#
dir=${HOME}
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
        setup_kubeconfig.sh [OPTION]

DESCRIPTION
	This script will setup the Kubernetes configuration file. The
	configuration file will be located at ~/.kube/kubeconfig. This
	script also creates soft link of the kubectl command into /usr/bin 
	and it appends the KUBECONFIG environmental variable to .bashrc.

        -h, --help
                help page.
        -g, --generate
                Inspect the jdbc connection.

INSTRUCTIONS
	1. Copy this script to the ecs master.
		scp setup_kubeconfig.sh ecs-1.example.com:~/bin/
	2. Login into the ECS master.
		ssh ecs-1.example.com
	3. Run this script in the admin user home directory.
		setup_kubeconfig.sh --generate
	4. Source the .bashrc file.
		source .bashrc
	5. Test.
	   	kubectl config view
	   	kubectl get nodes

EXAMPLE
	The CLI option is:
		kubectl --kubeconfig ${HOME}/.kube/external_kubeconfig get nodes
EOF
	exit
}

function check_arg() {
# Check if arguments exits

        if [ ${numargs} -ne "$1" ]; then
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

function gen_kubeconfig() {
# Generate Kubeconfig file. 

	if [ ! -d ${HOME}/.kube ]; then
		mkdir ${HOME}/.kube
	fi

	sudo sed -e 's/certificate-authority-data/#&/' -e "s/server: .*/server: https:\/\/`hostname`:6443/" -e '/server/a \ \ \ \ insecure-skip-tls-verify: true' /etc/rancher/rke2/rke2.yaml > ${HOME}/.kube/kubeconfig
}

function set_kubeconfig() {
# Describe function.

	grep KUBECONFIG ${HOME}/.bashrc > /dev/null 2>&1
	result=$?
	if [ ${result} -ne 0 ]; then
		echo "Set the environmental variable for kubeconfig"
		echo "# Kube Config " >> ${HOME}/.bashrc
		echo "export PATH=$PATH:/var/lib/rancher/rke2/bin" >> ${HOME}/.bashrc
		echo "export KUBECONFIG=${HOME}/.kube/kubeconfig" >> ${HOME}/.bashrc
	fi

	if [ ! -f /usr/bin/kubectl ]; then
		sudo ln -s /opt/cloudera/parcels/ECS/installer/install/bin/linux/kubectl /usr/bin/kubectl
	fi 
}

function msg_kubeconfig() {
# Message the user next action
	
	echo "To verify run:"
	echo "	source .bashrc"
	echo "  kubectl"
	echo "  kubectl config view"
	echo "  kubectl get nodes"
}

function run_option() {
# Case statement for options.

    	case "${option}" in
        	-h | --help)
            		check_arg 1	
           		get_help | less
            		;;
        	-g | --generate)
            		check_arg 1	
	    		gen_kubeconfig
	    		set_kubeconfig
			msg_kubeconfig
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

# MAIN

main "$@"
exit 0

