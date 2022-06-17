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

# Title: setup_nifi_user.sh
# Author: WKD
# Date: 180317 
# Purpose: This script setups the $USER to access the nifi user on any
# host in the cluster. The public key for ${USER} will be located in 
# nifi users .ssh dir. The user ${USER} can now transfer the 
# flow.xml.gz file with: 
# scp /var/lib/nifi/conf/flow.xml.gz nifi@NIFI_HOST:/var/lib/nifi/conf/flow.xm.gz"
# Additionally, we are distributing the private key. This allows the user
# nifi to access any host holding the public key. This is required to
# support processors such as SFTP with passwordless ssh.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
NUMARGS=$#
DIR=${HOME}
AUTHKEY=authorized_keys
PRIVKEY=id_rsa
HOSTLIST="flow01 flow02 flow03"
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${DIR}/log/setup-nifi-user.log
SUCCESS="no"

# FUNCTIONS
function usage() {
	echo "Usage: $(basename $0)" 
	exit 
}

function call_include() {
# Test for script and run functions

        if [ -f ${DIR}/bin/include.sh ]; then
                source ${DIR}/bin/include.sh
        else
                echo "ERROR: The file ${DIR}/bin/include.sh not found."
                echo "This required file provides supporting functions."
		exit 1
        fi
}

function copy_config() {
# Setup ssh for NiFi on cluster 

	echo "Setup up ssh for NiFi user at ${DATETIME}" | tee >> ${LOGFILE}

        for HOST in $(echo ${HOSTLIST}); do
		ssh -t ${HOST} "sudo mkdir /home/nifi/.ssh"
		scp ${DIR}/conf/nifi/ssh_config ${HOST}:/tmp/ssh_config
		ssh -t ${HOST} "sudo mv /tmp/ssh_config /home/nifi/.ssh/ssh_config"
		ssh -t ${HOST} "sudo chown nifi /home/nifi/.ssh/ssh_config"
		ssh -t ${HOST} "sudo chmod 600 /home/nifi/.ssh/ssh_config"

		if [ $? -eq 0 ]; then
			SUCCESS=yes
		fi
        done
}

function copy_ssh() {
# Setup ssh for NiFi on cluster 

	echo "Push ssh keys for NiFi user at ${DATETIME}" | tee >> ${LOGFILE}

        for HOST in $(echo ${HOSTLIST}); do
		ssh -t ${HOST} "sudo cp ${HOME}/.ssh/${AUTHKEY} /home/nifi/.ssh/${AUTHKEY}"
		ssh -t ${HOST} "sudo cp ${HOME}/.ssh/${PRIVKEY} /home/nifi/.ssh/${PRIVKEY}"
		ssh -t ${HOST} "sudo chmod 600 /home/nifi/.ssh/${AUTHKEY}"
		ssh -t ${HOST} "sudo chmod 600 /home/nifi/.ssh/${PRIVKEY}"
		ssh -t ${HOST} "sudo chmod 700 /home/nifi/.ssh"
		ssh -t ${HOST} "sudo chown -R nifi:nifi /home/nifi/.ssh"

		if [ $? -eq 0 ]; then
			SUCCESS=yes
		fi
        done
}

function create_dir() {
# Create a data directory for the user nifi on HDF hosts.

	for HOST in $(echo ${HOSTLIST}); do
		ssh -tt ${HOST} "sudo mkdir -p /data/nifi"
		ssh -tt ${HOST} "sudo chown -R nifi:nifi /data/nifi"
	done
}

function explain() {

	if [ ${SUCCESS} == "yes" ]; then
		echo "The public key for ${USER} is now located in nifi users .ssh dir"
		echo "The user ${USER} can now transfer the flow.xml.gz file with: "
		echo "scp /var/lib/nifi/conf/flow.xml.gz nifi@NIFI_HOST:/var/lib/nifi/conf/flow.xm.gz"
	else
		echo "The install of ssh keys failed for user nifi"
	fi
}

# MAIN
# Source functions
call_include

# Run checks
check_sudo
setup_log ${LOGFILE}

# Run option
copy_config
copy_ssh
create_dir
explain
