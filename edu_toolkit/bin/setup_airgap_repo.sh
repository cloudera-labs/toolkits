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

# Title: setup_airgap_repo.sh
# Author: WKD
# Date: 210601
# Purpose: This script installs a local repository in support of
# Cloudera Manager, Cloudera Runtime, and Cloudera Data Flow. 
# This script should be run on the host supporting the local repo.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
num_arg=$#
option=$1
dir=${HOME}
paywall=[username]:[password]
repo_dir=/home/training/software
cm_ver=7.4.4
cdh_ver=7.1.7
cdh_parcel=CDH-7.1.7-1.cdh7.1.7.p78.21656418-el7.parcel
keytrustee_parcel=KEYTRUSTEE_SERVER-7.1.7.78-1.keytrustee7.1.7.78.p0.21656418-el7.parcel
cfm_ver=2.1.4
cfm_parcel=CFM-2.1.4.1000-5-el7.parcel
nifi_jar=NIFI-1.16.0.2.1.4.1000-5.jar
nifi_registry_JAR=nifi_registry-1.16.0.2.1.4.1000-5.jar
nifi_standalone=nifi-1.16.0.2.1.4.1000-5-bin.tar.gz
spark_ver=3.1
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
	setup_airgap_repo.sh [OPTION]

DESCRIPTION
	This script installs a local repository in support of
	Cloudera Manager, Cloudera Runtime, and Cloudera Data Flow. 
	This script should be run on the host supporting the local 
	repository. 

	Instructions:
	1. Request license to access Cloudera paywall.
	2. Set the paywall username:password variable
	3. Use Cloudera support matrix to ensure you have the correct 
	alignment for release version numbers.
	4. Edit the variable list for version numbers.
	5. Use Cloudera documentation for downloads to find the
	repo locations.
	6. Download only needed parcels. Use the curl command to 
	locate the required parcels.
		Example:
		training@cmhost:~$ paywall="4e9-9385-4a7e-32be13e:866a96"
		training@cmhost:~$ curl https://${paywall}@archive.cloudera.com/p/cdh7/7.1.7.78/parcels/
	7. Edit the variables for the parcels.
	8. Edit the script for the path ways to the parcels.
	9. Run the script.
		Example:
		training@cmost:~$ setup_airgap_repo.sh --all

	-h, --help
		Help page
	-a, --all
		Build the entire repo"
	-c, --cm
		Build the repo for Cloudera Manager"
	-d, --cdh
		Build the repo for CDP Runtime"
	-f, --cfm
		Build the repo for CFM"
	-h, --httpd
		Install httpd"
	-s, --spark3
		Build the repo for Spark3"
EOF
        exit
}

function check_arg() {
# Check if arguments exits

        if [ ${num_arg} -ne "$1" ]; then
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

	if [ ! -d ${repo_dir}/cloudera-repos/cm7 ]; then
		sudo mkdir -p ${repo_dir}/cloudera-repos/cm7/${cm_ver}
	fi
	if [ ! -d ${repo_dir}/cloudera-repos/cdh7 ]; then
		sudo mkdir -p ${repo_dir}/cloudera-repos/cdh7/${cdh_ver}
	fi
	if [ ! -d ${repo_dir}/cloudera-repos/cfm2 ]; then
		sudo mkdir -p ${repo_dir}/cloudera-repos/cfm2/${cfm_ver}
	fi
	if [ ! -d ${repo_dir}/cloudera-repos/spark3 ]; then
		sudo mkdir -p ${repo_dir}/cloudera-repos/spark3/${spark_ver}
	fi
}

function repo_cm() {
# Pull down and setup CM tarfile

	echo "Install CM repo"

	# Install repo from Cloudera paywall 

	sudo wget https://${paywall}@archive.cloudera.com/p/cm7/7.4.4-24429768/repo-as-tarball/cm${cm_ver}-redhat7.tar.gz -P ${repo_dir}/cloudera-repos/cm7/${cm_ver}/
	sudo tar xvfz ${repo_dir}/cloudera-repos/cm7/${cm_ver}/cm${cm_ver}-redhat7.tar.gz -C ${repo_dir}/cloudera-repos/cm7/${cm_ver}/ --strip-components=1

	sudo rm ${repo_dir}/cloudera-repos/cm7/${cm_ver}/cm${cm_ver}-redhat7.tar.gz
	sudo chmod -R ugo+rX ${repo_dir}/cloudera-repos/cm7
}

function repo_cdh() {
# Pull down CDH parcel

	echo "Install CDH repo"

	# Install repo from Cloudera paywall 
	sudo wget https://${paywall}@archive.cloudera.com/p/cdh7/7.1.7.78/parcels/manifest.json -O ${repo_dir}/cloudera-repos/cdh7/${cdh_ver}/manifest.json
	sudo wget https://${paywall}@archive.cloudera.com/p/cdh7/7.1.7.78/parcels/${cdh_parcel} -O ${repo_dir}/cloudera-repos/cdh7/${cdh_ver}/${cdh_parcel}
	sudo wget https://${paywall}@archive.cloudera.com/p/cdh7/7.1.7.78/parcels/${cdh_parcel}.sha1 -O ${repo_dir}/cloudera-repos/cdh7/${cdh_ver}/${cdh_parcel}.sha1
	sudo wget https://${paywall}@archive.cloudera.com/p/cdh7/7.1.7.78/parcels/${cdh_parcel}.sha256 -O ${repo_dir}/cloudera-repos/cdh7/${cdh_ver}/${cdh_parcel}.sha256

	sudo chmod -R ugo+rX ${repo_dir}/cloudera-repos/cdh7
}

function repo_keytrustee() {
# Pull down Keytrustee parcel

	echo "Install Keytrustee repo"

	# Install repo from Cloudera paywall 
	sudo wget https://${paywall}@archive.cloudera.com/p/cdh7/7.1.7.78/parcels/${keytrustee_parcel} -O ${repo_dir}/cloudera-repos/cdh7/${cdh_ver}/${keytrustee_parcel}
	sudo wget https://${paywall}@archive.cloudera.com/p/cdh7/7.1.7.78/parcels/${keytrustee_parcel}.sha -O ${repo_dir}/cloudera-repos/cdh7/${cdh_ver}/${keytrustee_parcel}.sha
}

function repo_cfm() {
# Pull down CFM manifest, parcel, and sha

	echo "Install CFM repo"

	# Install repo from Cloudera paywall 
	sudo wget https://${paywall}@archive.cloudera.com/p/cfm2/2.1.4.1000/redhat7/yum/tars/parcel/manifest.json -O ${repo_dir}/cloudera-repos/cfm2/${cfm_ver}/manifest.json
	sudo wget https://${paywall}@archive.cloudera.com/p/cfm2/2.1.4.1000/redhat7/yum/tars/parcel/${cfm_parcel} -O ${repo_dir}/cloudera-repos/cfm2/${cfm_ver}/${cfm_parcel} 
	sudo wget https://${paywall}@archive.cloudera.com/p/cfm2/2.1.4.1000/redhat7/yum/tars/parcel/${cfm_parcel}.sha -O ${repo_dir}/cloudera-repos/cfm2/${cfm_ver}/${cfm_parcel}.sha 

	sudo chmod -R ugo+rX ${repo_dir}/cloudera-repos/cfm2
}

function repo_csd() {
# The CSD files are need by Cloudera Manager to install the services. 
# They are jar files to be placed into /opt/cloudera-repos/csd on the CM host.

	echo "Install CSD repo in support of CFM"
	sudo wget https://${paywall}@archive.cloudera.com/p/cfm2/2.1.4.1000/redhat7/yum/tars/parcel/${nifi_jar} -O ${repo_dir}/cloudera-repos/cfm2/${cfm_ver}/${nifi_jar}
	sudo wget https://${paywall}@archive.cloudera.com/p/cfm2/2.1.4.1000/redhat7/yum/tars/parcel/${nifi_registry_JAR} -O ${repo_dir}/cloudera-repos/cfm2/${cfm_ver}/${nifi_registry_JAR}
}

function repo_nifi() {
# NiFi standalone file

	sudo wget https://${paywall}@archive.cloudera.com/p/cfm2/2.1.4.1000/redhat7/yum/tars/nifi/${nifi_standalone} -O ${repo_dir}/cloudera-repos/cfm2/${cfm_ver}/${nifi_standalone}
}

function repo_spark3() {
# Install Spark3 Repo 

	sudo wget https://${paywall}@archive.cloudera.com/p/spark3/3.1.7270.0/parcels/manifest.json -O ${repo_dir}/cloudera-repos/spark3/${spark_ver}/manifest.json
	sudo wget https://${paywall}@archive.cloudera.com/p/spark3/3.1.7270.0/parcels/SPARK3-3.1.1.3.1.7270.0-253-1.p0.11638568-el7.parcel -O ${repo_dir}/cloudera-repos/spark3/${spark_ver}/SPARK3-3.1.1.3.1.7270.0-253-1.p0.11638568-el7.parcel
	sudo wget https://${paywall}@archive.cloudera.com/p/spark3/3.1.7270.0/parcels/SPARK3-3.1.1.3.1.7270.0-253-1.p0.11638568-el7.parcel.sha1 -O ${repo_dir}/cloudera-repos/spark3/${spark_ver}/SPARK3-3.1.1.3.1.7270.0-253-1.p0.11638568-el7.parcel.sha1
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
	echo "http://local-repo.example.com:8064/cloudera-repos"
}

function run_option() {
# Case statement for options.

	case "${option}" in
		-h | --help)
			get_help
			;;
		-a | --all)
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
		-c | --cm)
			check_arg 1
			make_dir
			repo_cm
			restart_http
			check_repo
			;;
		-d | --cdh)
			check_arg 1
			make_dir
			repo_cdh
			repo_keytrustee
			restart_http
			check_repo
			;;
		-f | --cfm)
			check_arg 1
			make_dir
			repo_cfm
			repo_csd
			repo_nifi
			restart_http
			check_repo
			;;
		-h | --httpd)
			check_arg 1
			install_httpd
			;;
		-s | --spark3)
			check_arg 1
			make_dir
			repo_spark3
			;;
		*)
			usage
			;;
	esac
}

function main() {

	# Run option
	run_option

	# Review log file
	#echo "Review log file at ${logfile}"
}

#MAIN
main "$@"
exit 0
