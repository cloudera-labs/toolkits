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

# Title: setup_paywall_repo.sh
# Author: WKD
# Date: 210601
# Purpose: This script installs a local repository in support of
# Cloudera Manager, Cloudera Runtime, and Cloudera Data Flow. 
# This script should be run on the host supporting the local 
# repository. 
# Instructions:
# 1. Request license to access Cloudera paywall.
# 2. Set the paywall username:password variable
# 3. Use Cloudera support matrix to ensure you have the correct 
# alignment for release version numbers.
# 4. Edit the variable list for version numbers.
# 5. Use Cloudera documentation for downloads to find the
# repo locations.
# 6. Download only needed parcels. Use the curl command to 
# locate the required parcels.
# Example:
# training@cmhost:~$ PAYWALL="4e9-9385-4a7e-32be13e:866a96"
# training@cmhost:~$ curl https://${PAYWALL}@archive.cloudera.com/p/cdh7/7.1.7.78/parcels/
# 7. Edit the variables for the parcels.
# 8. Edit the script for the path ways to the parcels.
# 9. Run the script.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
NUMARGS=$#
OPTION=$1
DIR=${HOME}
PAYWALL=[username]:[password]
REPO_DIR=/home/training/software
CM_VER=7.4.4
CDH_VER=7.1.7
CDH_PARCEL=CDH-7.1.7-1.cdh7.1.7.p78.21656418-el7.parcel
KEYTRUSTEE_PARCEL=KEYTRUSTEE_SERVER-7.1.7.78-1.keytrustee7.1.7.78.p0.21656418-el7.parcel
CFM_VER=2.1.4
CFM_PARCEL=CFM-2.1.4.1000-5-el7.parcel
NIFI_JAR=NIFI-1.16.0.2.1.4.1000-5.jar
NIFIREGISTRY_JAR=NIFIREGISTRY-1.16.0.2.1.4.1000-5.jar
NIFI_STANDALONE=nifi-1.16.0.2.1.4.1000-5-bin.tar.gz
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${DIR}/log/setup-local-repo.log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [all|cm|cdh|cfm|httpd]"
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


function make_dir() {
# Create Cloudera repos directory

	if [ ! -d ${REPO_DIR}/cloudera/cm7 ]; then
		sudo mkdir -p ${REPO_DIR}/cloudera/cm7/${CM_VER}
	fi
	if [ ! -d ${REPO_DIR}/cloudera/cdh7 ]; then
		sudo mkdir -p ${REPO_DIR}/cloudera/cdh7/${CDH_VER}
	fi
	if [ ! -d ${REPO_DIR}/cloudera/cfm2 ]; then
		sudo mkdir -p ${REPO_DIR}/cloudera/cfm2/${CFM_VER}
	fi
}

function repo_cm() {
# Pull down and setup CM tarfile

	echo "Install CM repo"

	# Install repo from Cloudera paywall 

	sudo wget https://${PAYWALL}@archive.cloudera.com/p/cm7/7.4.4-24429768/repo-as-tarball/cm${CM_VER}-redhat7.tar.gz -P ${REPO_DIR}/cloudera/cm7/${CM_VER}/
	sudo tar xvfz ${REPO_DIR}/cloudera/cm7/${CM_VER}/cm${CM_VER}-redhat7.tar.gz -C ${REPO_DIR}/cloudera/cm7/${CM_VER}/ --strip-components=1

	sudo rm ${REPO_DIR}/cloudera/cm7/${CM_VER}/cm${CM_VER}-redhat7.tar.gz
	sudo chmod -R ugo+rX ${REPO_DIR}/cloudera/cm7
}

function repo_cdh() {
# Pull down CDH parcel

	echo "Install CDH repo"

	# Install repo from Cloudera paywall 
	sudo wget https://${PAYWALL}@archive.cloudera.com/p/cdh7/7.1.7.78/parcels/manifest.json -O ${REPO_DIR}/cloudera/cdh7/${CDH_VER}/manifest.json
	sudo wget https://${PAYWALL}@archive.cloudera.com/p/cdh7/7.1.7.78/parcels/${CDH_PARCEL} -O ${REPO_DIR}/cloudera/cdh7/${CDH_VER}/${CDH_PARCEL}
	sudo wget https://${PAYWALL}@archive.cloudera.com/p/cdh7/7.1.7.78/parcels/${CDH_PARCEL}.sha1 -O ${REPO_DIR}/cloudera/cdh7/${CDH_VER}/${CDH_PARCEL}.sha1
	sudo wget https://${PAYWALL}@archive.cloudera.com/p/cdh7/7.1.7.78/parcels/${CDH_PARCEL}.sha256 -O ${REPO_DIR}/cloudera/cdh7/${CDH_VER}/${CDH_PARCEL}.sha256

	sudo chmod -R ugo+rX ${REPO_DIR}/cloudera/cdh7
}

function repo_keytrustee() {
# Pull down Keytrustee parcel

	echo "Install Keytrustee repo"

	# Install repo from Cloudera paywall 
	sudo wget https://${PAYWALL}@archive.cloudera.com/p/cdh7/7.1.7.78/parcels/${KEYTRUSTEE_PARCEL} -O ${REPO_DIR}/cloudera/cdh7/${CDH_VER}/${KEYTRUSTEE_PARCEL}
	sudo wget https://${PAYWALL}@archive.cloudera.com/p/cdh7/7.1.7.78/parcels/${KEYTRUSTEE_PARCEL}.sha -O ${REPO_DIR}/cloudera/cdh7/${CDH_VER}/${KEYTRUSTEE_PARCEL}.sha
}

function repo_cfm() {
# Pull down CFM manifest, parcel, and sha

	echo "Install CFM repo"

	# Install repo from Cloudera paywall 
	sudo wget https://${PAYWALL}@archive.cloudera.com/p/cfm2/2.1.4.1000/redhat7/yum/tars/parcel/manifest.json -O ${REPO_DIR}/cloudera/cfm2/${CFM_VER}/manifest.json
	sudo wget https://${PAYWALL}@archive.cloudera.com/p/cfm2/2.1.4.1000/redhat7/yum/tars/parcel/${CFM_PARCEL} -O ${REPO_DIR}/cloudera/cfm2/${CFM_VER}/${CFM_PARCEL} 
	sudo wget https://${PAYWALL}@archive.cloudera.com/p/cfm2/2.1.4.1000/redhat7/yum/tars/parcel/${CFM_PARCEL}.sha -O ${REPO_DIR}/cloudera/cfm2/${CFM_VER}/${CFM_PARCEL}.sha 

	sudo chmod -R ugo+rX ${REPO_DIR}/cloudera/cfm2
}

function repo_csd() {
# The CSD files are need by Cloudera Manager to install the services. 
# They are jar files to be placed into /opt/cloudera/csd on the CM host.

	echo "Install CSD repo in support of CFM"
	sudo wget https://${PAYWALL}@archive.cloudera.com/p/cfm2/2.1.4.1000/redhat7/yum/tars/parcel/${NIFI_JAR} -O ${REPO_DIR}/cloudera/cfm2/${CFM_VER}/${NIFI_JAR}
	sudo wget https://${PAYWALL}@archive.cloudera.com/p/cfm2/2.1.4.1000/redhat7/yum/tars/parcel/${NIFIREGISTRY_JAR} -O ${REPO_DIR}/cloudera/cfm2/${CFM_VER}/${NIFIREGISTRY_JAR}
}

function repo_nifi() {
# NiFi standalone file

	sudo wget https://${PAYWALL}@archive.cloudera.com/p/cfm2/2.1.4.1000/redhat7/yum/tars/nifi/${NIFI_STANDALONE} -O ${REPO_DIR}/cloudera/cfm2/${CFM_VER}/${NIFI_STANDALONE}
}

function install_httpd() {
# Install http server

	if [ ! -f "/etc/httpd/conf/httpd.conf" ]; then
		echo "Install httpd"
		sudo yum install -y httpd
		sleep 3
        grep 8064 /etc/httpd/conf/httpd.conf
        result=$?
        if [[ ! result -eq 0 ]]; then
            sudo sed -i -e 's/Listen 80/Listen 8064/g' /etc/httpd/conf/httpd.conf
        fi

       	sudo systemctl enable httpd
       	sudo systemctl start httpd
   		sudo systemctl status httpd	
	fi
}

function restart_http() {
# Restart the HTTP service
	
	if [ -f /etc/httpd/conf/httpd.conf ]; then
		sudo systemctl restart httpd
	fi
}

function check_repo() {

	echo "Verify the repos at:"
	echo "http://local-repo.example.com:8064/cloudera"
}

function run_option() {
# Case statement for options.

	case "${OPTION}" in
		-h | --help)
			usage
			;;
		all)
			check_arg 1
			make_dir
			repo_cm
			repo_cdh
			repo_keytrustee
			repo_cfm
			repo_csd
			repo_nifi
			restart_http
			check_repo
			;;
		cm)
			check_arg 1
			make_dir
			repo_cm
			restart_http
			check_repo
			;;
		cdh)
			check_arg 1
			make_dir
			repo_cdh
			repo_keytrustee
			restart_http
			check_repo
			;;
		cfm)
			check_arg 1
			make_dir
			repo_cfm
			repo_csd
			repo_nifi
			restart_http
			check_repo
			;;
		httpd)
			check_arg 1
			install_httpd
			;;

		*)
			usage
			;;
	esac
}

# Main
run_option
