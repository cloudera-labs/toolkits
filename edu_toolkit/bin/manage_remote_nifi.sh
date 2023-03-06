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
# IMPORTANT ENSURE JAVA_dir and PATH are set for root

# Title: manage_remote_nifi.sh
# Author: WKD
# Date: 190129
# Purpose: This script installs a remote NiFi from the tar file
# We have to copy in the tar file onto the Ubuntu server and then
# onto the client designated to be the remote NiFi.
# Copy and run this script to the client designated
# to support a remote NiFi.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
num_arg=$#
dir=${HOME}
option=$1
cloudera_license=$2
nifi_remote_host=$2
admin_user=training
nifi_ver=nifi-1.18.0.2.1.5.0-215
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
        manage_remote_nifi.sh [OPTION]

DESCRIPTION
	This tool install, configures and starts/stops a remote NiFi
	instance. The tool can also configure a NiFi user to have 
	the correct configuration files and keys to support processes,
	such as fetchhdfs.

        -h, --help
                Help page
        -g, --get
		--get <cloudera_license:cloudera_password>
                Download the NiFi tar file.
        -i, --install
		--install <nifi_remote_host>
                Install a remote NiFi. Extract the remote
		tar file, install NiFi, and configure NiFi.
	-p, --push
		--push <nifi_remote_host>
		Push the NiFi tar file to the remote host.
	-s, --start
		--start <nifi_remote_host>
		Start the remote NiFi instance.
	-t, --stop
		--stop <nifi_remote_host>
		Start the remote NiFi instance.
	-u, --user
		Create and configure the NiFi user on NiFi hosts
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
        fi
}

function get_file() {

        wget https://${cloudera_license}@archive.cloudera.com/p/cfm2/2.1.5.0/redhat7/yum/tars/nifi/${nifi_ver}-bin.tar.gz -O ${dir}/${nifi_ver}-bin.tar.gz
}

function push_tar() {

        check_file ${dir}/lib/${nifi_ver}-bin.tar.gz
        scp ${dir}/lib/${nifi_ver}-bin.tar.gz ${admin_user}@${nifi_remote_host}:/tmp/${nifi_ver}-bin.tar.gz
}

function install_nifi() {

        ssh ${admin_user}@${nifi_remote_host} -C "sudo mkdir -p /opt/nifi"
        ssh ${admin_user}@${nifi_remote_host} -C "sudo tar -xvzf /tmp/${nifi_ver}-bin.tar.gz -C /opt/nifi"
        ssh ${admin_user}@${nifi_remote_host} -C "sudo rm /opt/nifi/current"
        ssh ${admin_user}@${nifi_remote_host} -C "sudo ln -s /opt/nifi/${nifi_ver} /opt/nifi/current"
}


function config_nifi() {
        ssh ${admin_user}@${nifi_remote_host} -C "sudo cp /opt/nifi/current/conf/nifi.properties /opt/nifi/current/conf/nifi.properties.org"
        ssh ${admin_user}@${nifi_remote_host} -C "sudo sed -i -e 's/8080/8060/g' /opt/nifi/current/conf/nifi.properties"
        ssh ${admin_user}@${nifi_remote_host} -C "sudo sed -i -e 's/nifi.remote.input.host=/nifi.remote.input.host=${nifi_remote_host}/g' /opt/nifi/current/conf/nifi.properties"
        ssh ${admin_user}@${nifi_remote_host} -C "sudo sed -i -e 's/nifi.remote.input.socket.port=/nifi.remote.input.socket.port=8055/g' /opt/nifi/current/conf/nifi.properties"
}


function copy_config() {
# Setup ssh for NiFi on cluster

        echo "Setup up ssh for NiFi user at  | tee >> ${logfile}

        for host in $(echo ${host_list}); do
                ssh -t ${host} "sudo mkdir /home/nifi/.ssh"
                scp ${dir}/conf/nifi/ssh_config ${host}:/tmp/ssh_config
                ssh -t ${host} "sudo mv /tmp/ssh_config /home/nifi/.ssh/ssh_config"
                ssh -t ${host} "sudo chown nifi /home/nifi/.ssh/ssh_config"
                ssh -t ${host} "sudo chmod 600 /home/nifi/.ssh/ssh_config"

                if [ $? -eq 0 ]; then
                        success=yes
                fi
        done
}

function copy_ssh() {
# Setup ssh for NiFi on cluster

        echo "Push ssh keys for NiFi user at  | tee >> ${logfile}

        for host in $(echo ${host_list}); do
                ssh -t ${host} "sudo cp ${HOME}/.ssh/${auth_key} /home/nifi/.ssh/${auth_key}"
                ssh -t ${host} "sudo cp ${HOME}/.ssh/${priv_key} /home/nifi/.ssh/${priv_key}"
                ssh -t ${host} "sudo chmod 600 /home/nifi/.ssh/${auth_key}"
                ssh -t ${host} "sudo chmod 600 /home/nifi/.ssh/${priv_key}"
                ssh -t ${host} "sudo chmod 700 /home/nifi/.ssh"
                ssh -t ${host} "sudo chown -R nifi:nifi /home/nifi/.ssh"

                if [ $? -eq 0 ]; then
                        success=yes
                fi
        done
}

function create_dir() {
# Create a data directory for the user nifi on HDF hosts.

        for host in $(echo ${host_list}); do
                ssh -tt ${host} "sudo mkdir -p /data/nifi"
                ssh -tt ${host} "sudo chown -R nifi:nifi /data/nifi"
        done
}

function msg_user() {

        if [ ${success} == "yes" ]; then
                echo "The public key for ${USER} is now located in nifi users .ssh dir"
                echo "The user ${USER} can now transfer the flow.xml.gz file with: "
                echo "scp /var/lib/nifi/conf/flow.xml.gz nifi@NIFI_host:/var/lib/nifi/conf/flow.xm.gz"
        else
                echo "The install of ssh keys failed for user nifi"
        fi
}

function start_nifi() {
	ssh ${admin_user}@${nifi_remote_host} -C "sudo -E /opt/nifi/current/bin/nifi.sh start"
	echo "Wait..."
	sleep 5
	ssh ${admin_user}@${nifi_remote_host} -C "sudo -E /opt/nifi/current/bin/nifi.sh status"
	echo
	echo "Reach NiFi Remote host at:"
	echo "http://${nifi_remote_host}:8060/nifi"
}

function stop_nifi() {
	ssh ${admin_user}@${nifi_remote_host} -C "sudo -E /opt/nifi/current/bin/nifi.sh stop"
	echo "Wait..."
	sleep 5
	ssh ${admin_user}@${nifi_remote_host} -C "sudo -E /opt/nifi/current/bin/nifi.sh status"
}

function run_option() {
# Case statement for options.

	case "${option}" in
		-h | --help)
			get_help
			;;
		-g | --get)
			check_arg 2
			get_file
			;;
		-i | --install)
			check_arg 2
			install_nifi
			config_nifi
			;;
		-p | --push)
			check_arg 2
			push_nifi
			;;
		-s | --start)
			check_arg 2
			start_nifi
			;;
		-t |--stop)
			check_arg 2
			stop_nifi
			;;
		-u | --user)
			check_arg 1
			copy_config
			copy_ssh
			create_dir
			msg_user
			;;
		*)
			usage
			;;
	esac
}

function main() {

	# Run checks
	call_include
	check_sudo

	# Run command
	run_option

	# Review log file
	#echo "Review log file at ${logfile}"
}

#MAIN
main "$@"
exit 0
