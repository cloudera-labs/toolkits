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
# Purpose: This script installs a local repository in support of
# Cloudera Manager and Cloudera Runtime. This script should be run 
# on the host supporting the local repository. 

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
NUMARGS=$#
DIR=${HOME}
CM_VER=$1
CDP_VER=$2
PAYWALL=[username]:[password]
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${DIR}/log/setup-local-repo.log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [cm_version_number] [cdp_version_number]"
        echo "Example: $(basename $0) 7.1.7 7.4.4"
        exit 1
}

function check_arg() {
# Check if arguments exits

        if [ ${NUMARGS} -ne "$1" ]; then
                usage
        fi
}

function check_file() {
# Check for a file

        FILE=$1
        if [ ! -f ${FILE} ]; then
                echo "ERROR: Input file ${FILE} not found"
                usage
        fi
}

function install_http() {
# Install http server

	if [ ! -d /var/www/html ]; then
		echo "Install httpd"
		sudo yum install -y httpd
		sleep 3
		sudo sed -i -e 's/80/8060/g' /etc/httpd/conf/httpd.conf
        	sudo systemctl enable httpd
        	sudo systemctl start httpd
   		sudo systemctl status httpd	
	fi
}

function make_dir() {
# Create Cloudera repos directory

	if [ ! -d /var/www/html/cloudera ]; then
		sudo mkdir -p /var/www/html/cloudera/cm7/${CM_VER}
		sudo mkdir -p /var/www/html/cloudera/cdh7
		sudo mkdir -p /var/www/html/cloudera/cfm2
	fi
}

function repo_cm() {
# Pull down and setup CM tarfile

	echo "Install CM repo"

	# Install repo from Cloudera paywall 
	sudo wget https://${PAYWALL}@archive.cloudera.com/p/cm7/${CM_VER}/repo-as-tarball/cm${CM_VER}-redhat7.tar.gz 
	sudo tar xvfz cm${CM_VER}-redhat7.tar.gz -C /var/www/html/cloudera/cm7 --strip-components=1

	sudo rm /var/www/html/cloudera/cm7/${CM_VER}/cm${CM_VER}-redhat7.tar.gz
	sudo chmod -R ugo+rX /var/www/html/cloudera/cm7
}

function repo_cdp() {
# Pull down CDH parcels

	echo "Install CDP repo"

	# Install repo from Cloudera paywall 
	sudo wget --recursive --no-parent --no-host-directories https://${PAYWALL}@archive.cloudera.com/p/cdh7/${CDP_VER}/parcels -P /var/www/html/cloudera

	sudo chmod -R ugo+rX /var/www/html/cloudera/cdh7
}

function repo_cfm() {
# Pull down CFM manifest, parcel, and sha

	echo "Install CFM repo"

	# Install repo from Cloudera paywall 
	sudo wget --recursive --no-parent --no-host-directories https://${PAYWALL}@archive.cloudera.com/p/cfm2/2.1.1.0/redhat7/yum/tars/parcel/manifest.json 
	sudo wget --recursive --no-parent --no-host-directories https://${PAYWALL}@archive.cloudera.com/p/cfm2/2.1.1.0/redhat7/yum/tars/parcel/CFM-2.1.1.0-13-el7.parcel 
	sudo wget --recursive --no-parent --no-host-directories https://${PAYWALL}@archive.cloudera.com/p/cfm2/2.1.1.0/redhat7/yum/tars/parcel/CFM-2.1.1.0-13-el7.parcel.sha

	sudo chmod -R ugo+rX /var/www/html/cloudera/cfm2
}

function repo_csd() {
# The CSD files are need by Cloudera Manager to install the services. 
# They are jar files to be placed into /opt/cloudera/csd on the CM host.

	echo "If required install CSD repo in support of CFM"
	wget --recursive --no-parent --no-host-directories https://${PAYWALL}@archive.cloudera.com/p/cfm2/2.1.1.0/redhat7/yum/tars/parcel/NIFI-1.13.2.2.1.1.0-13.jar
	wget --recursive --no-parent --no-host-directories https://${PAYWALL}@archive.cloudera.com/p/cfm2/2.1.1.0/redhat7/yum/tars/parcel/NIFIREGISTRY-0.8.0.2.1.1.0-13.jar
}

function restart_http() {
# Restart the HTTP service

	sudo systemctl restart httpd
}

function check_repo() {

	echo "Verify the repos at:"
	echo "http://local-repo.example.com:8060/cloudera"
}

# Main
check_arg 2 
install_http
make_dir
repo_cm
repo_cdp
repo_cfm
#repo_csd
restart_http
check_repo
