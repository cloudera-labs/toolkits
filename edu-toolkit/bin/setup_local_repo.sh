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
# IMPORTANT ENSURE JAVA_DIR and PATH are set for root

# Title: setup_local_repo.sh
# Author: WKD
# Date: 210601
# Purpose: This script creates a local repository on cmhost.example.com 
# in support of Cloudera Manager, Cloudera Runtime, and Cloudera Flow Management. 
# This script is making use of the tomcat server installed for guac. This script
# makes use of the parcels installed into /opt/cloudera/parcel-repo as part of 
# the build of the classroom environment.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
NUMARGS=$#
DIR=${HOME}
CM_VER=7.4.4
CDH_VER=7.1.7
CFM_VER=2.0.1
OPTION=$1
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${DIR}/log/setup-local-repo.log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [repo|list|delete]"
        exit 1
}

function call_include() {
# Test for include script.

        if [ -f ${DIR}/bin/include.sh ]; then
                source ${DIR}/bin//include.sh
        else
                echo "ERROR: The file ${DIR}/bin/include.sh not found."
                echo "This required file provides supporting functions."
                exit 1
        fi
}

function install_http() {
# Install http server

	if [ ! -d ${DIR}/software ]; then
		echo "Install httpd"
		sudo yum install -y httpd
		sleep 3
		sudo sed -i -e 's/LISTEN 80/LISTEN 8060/g' /etc/httpd/conf/httpd.conf
        	sudo systemctl enable httpd
        	sudo systemctl start httpd
   		sudo systemctl status httpd	
	fi
}

function make_dir() {
# Create Cloudera repos directory

	if [ ! -d ${DIR}/software/cloudera/cdh7 ]; then
		sudo mkdir -p ${DIR}/software/cloudera/cm7/${CM_VER}
		sudo mkdir -p ${DIR}/software/cloudera/cdh7/${CDH_VER}
		sudo mkdir -p ${DIR}/software/cloudera/cfm2/${CFM_VER}
		sudo chown -R training:training ${DIR}/software/cloudera
	fi
}

#function make_dir() {
# Create Cloudera repos directory
#
#	if [ ! -d ${DIR}/software/cloudera ]; then
#		sudo mkdir -p ${DIR}/software/cloudera/cm7/
#		sudo mkdir -p ${DIR}/software/cloudera/cdh7/${CDH_VER}
#		sudo mkdir -p ${DIR}/software/cloudera/cfm2/${CFM_VER}
# 	fi
#}

function repo_cm() {
# Move the CM repo files located in ${DIR}/software.
# This is really only done for consistency.  

	echo "Install CM repo"
	
	sudo cp ${DIR}/software/cm${CM_VER} ${DIR}/software/cloudera/cm7/${CM_VER}
	sudo chown -R training:training ${DIR}/software/cloudera/cm7
	sudo chmod -R ugo+rX ${DIR}/software/cloudera/cm7
}

function repo_cdh() {
# Copy over the CDH parcels and checksum into ${DIR}/software.

	echo "Install CDP repo"

	# Install repo from Cloudera paywall 
	sudo cp /opt/cloudera/parcel-repo/CDH*  ${DIR}/software/cloudera/cdh7/${CDH_VER}
	sudo rm -r ${DIR}/software/cloudera/cdh7/CDH*torrent
	sudo chown -R training:training ${DIR}/software/cloudera/cdh7
	sudo chmod -R ugo+rX ${DIR}/software/cloudera/cdh7
}

function repo_keytrustee() {
# Copy over the keytrustee parcels and checksum into ${DIR}/software.

	echo "Install Keytrustee repo"

	# Install repo from Cloudera paywall 
	sudo cp /opt/cloudera/parcel-repo/KEYTRUSTEE*  ${DIR}/software/cloudera/cdh7/${CDH_VER}
	sudo rm -r ${DIR}/software/cloudera/cdh7/KEYTRUSTEE*torrent
	sudo chown -R training:training ${DIR}/software/cloudera/cdh7
	sudo chmod -R ugo+rX ${DIR}/software/cloudera/cdh7
}

function repo_cfm() {
# Copy over the CFM manifest, parcel, and sha located into ${DIR}/software.

	echo "Install CFM repo"

	# Install repo from Cloudera paywall 
	sudo cp /opt/cloudera/parcel-repo/CFM*  ${DIR}/software/cloudera/cfm2/${CFM_VER}
	sudo rm -r ${DIR}/software/cloudera/cfm2/CFM*torrent
	sudo chown -R training:training ${DIR}/software/cloudera/cfm2
	sudo chmod -R ugo+rX ${DIR}/software/cloudera/cfm2
}

function repo_csd() {
# The CSD files are need by Cloudera Manager to install the services. 
# They are jar files to be placed into /opt/cloudera/csd on the CM host.

	echo "If required install CSD repo in support of CFM"
	# Install repo from Cloudera paywall 
	sudo cp /opt/cloudera/parcel-repo/*CSD*  ${DIR}/software/cloudera/cfm2/
	sudo chown -R training:training ${DIR}/software/cloudera/cfm2
	sudo chmod -R ugo+rX ${DIR}/software/cloudera/cfm2
}

function restart_http() {
# Restart the HTTP service

	sudo systemctl restart httpd
}

function check_repo() {

	echo "Verify the repos at:"
	echo "http://cmhost.example.com:8060/cloudera"
}

function list_repo() {

	ls -R ${DIR}/software/cloudera/
}

function delete_repo() {
# delete the repo

	echo -n "Confirm delete. "
	check_continue
	if [ -d ${DIR}/software/cloudera ]; then
		sudo rm -r -f ${DIR}/software/cloudera
	fi
}

function run_option() {
# Case statement for options.

        case "${OPTION}" in
                -h | --help)
                        usage
                        ;;
                repo)
                        check_arg 1
			make_dir
			repo_cm
			repo_cdh
			repo_cfm
			repo_keytrustee
			#repo_csd
			check_repo
                        ;;
                list)
                        check_arg 1
                        list_repo
			check_repo
                        ;;
                delete)
                        check_arg 1
                        delete_repo
                        ;;
                *)
                        usage
                        ;;
        esac
}

# MAIN
# Source functions
call_include

# Run checks
check_sudo

# Run setups
#setup_log ${LOGFILE}

# Run option
run_option
