#!/bin/bash

# This script is for training purposes only and is to be used only
# in support of approved training. The author assumes no liability
# for use outside of a training environments. Unless required by
# applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.
# IMPORTANT ENSURE JAVA_DIR and PATH are set for root

# Title: setup_remote_nifi.sh
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
NUMARGS=$#
DIR=${HOME}
NIFI_REMOTE_HOST=$1
NIFI_VER=nifi-1.11.4.3.5.1.0-17
NIFI_TAR=${NIFI_VER}-bin.tar.gz
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${DIR}/log/setup-remote-nifi.log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [nifi_remote_host]"
        exit 1
}

function call_include() {
# Test for script and run functions

        if [ -f ${DIR}/bin/include.sh ]; then
                source ${DIR}/bin/include.sh
        else
                echo "ERROR: The file ${DIR}/bin/include.sh not found."
                echo "This required file provides supporting functions."
        fi
}

function get_file() {
	wget https://user:password@archive.cloudera.com/p/HDF/3.5.1.0/nifi-1.11.4.3.5.1.0-17-bin.tar.gz -O /home/sysadmin/lib/nifi-1.11.4.3.5.1.0-17-bin.tar.gz
}


function push_tar() {

	check_file ${DIR}/lib/${NIFI_TAR}
	scp ${DIR}/lib/${NIFI_TAR} sysadmin@${NIFI_REMOTE_HOST}:/tmp/
}

function install_nifi() {
	
	ssh sysadmin@${NIFI_REMOTE_HOST} -C "sudo mkdir -p /opt/nifi"
	ssh sysadmin@${NIFI_REMOTE_HOST} -C "sudo tar -xvf /tmp/${NIFI_TAR} -C /opt/nifi"
	ssh sysadmin@${NIFI_REMOTE_HOST} -C "sudo rm /opt/nifi/current"
	ssh sysadmin@${NIFI_REMOTE_HOST} -C "sudo ln -s /opt/nifi/${NIFI_VER} /opt/nifi/current"
}

function config_nifi() {
 	ssh sysadmin@${NIFI_REMOTE_HOST} -C "sudo cp /opt/nifi/current/conf/nifi.properties /opt/nifi/current/conf/nifi.properties.org"
	ssh sysadmin@${NIFI_REMOTE_HOST} -C "sudo sed -i -e 's/8080/9090/g' /opt/nifi/current/conf/nifi.properties"
	ssh sysadmin@${NIFI_REMOTE_HOST} -C "sudo sed -i -e 's/nifi.remote.input.host=/nifi.remote.input.host=${NIFI_REMOTE_HOST}/g' /opt/nifi/current/conf/nifi.properties"
	ssh sysadmin@${NIFI_REMOTE_HOST} -C "sudo sed -i -e 's/nifi.remote.input.socket.port=/nifi.remote.input.socket.port=8055/g' /opt/nifi/current/conf/nifi.properties"
}

function start_nifi() {
	ssh sysadmin@${NIFI_REMOTE_HOST} -C "sudo -E /opt/nifi/current/bin/nifi.sh start"
	sleep 5
	ssh sysadmin@${NIFI_REMOTE_HOST} -C "sudo -E /opt/nifi/current/bin/nifi.sh status"
	echo
	echo "Reach NiFi Remote host at:"
	echo "http://${NIFI_REMOTE_HOST}:9090/nifi"
}

# MAIN
call_include
check_arg 1 
#get_file
push_tar
install_nifi
config_nifi
start_nifi
