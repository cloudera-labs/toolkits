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

# Title: setup_cm_repo.sh
# Author: WKD
# Date: 210601
# Purpose: This script installs a local repository in support of
# Cloudera Manager. This script should be run 
# on the host supporting the local repository. 

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
NUMARGS=$#
DIR=${HOME}
CM_VER=$1
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${DIR}/log/setup-cm-repo.log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [cm_version_number]"
        echo "Example: $(basename $0) 7.4.4"
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

	if [ ! -d /var/www/html/cloudera ]; then
		echo "Install httpd"
		sudo yum install -y httpd
		sleep 3
		sudo sed -i -e 's/80/8064/g' /etc/httpd/conf/httpd.conf
        	sudo systemctl enable httpd
        	sudo systemctl start httpd
   		sudo systemctl status httpd	
	fi
}

function make_dir() {
# Create Cloudera repos directory

	if [ ! -d /var/www/html/cloudera ]; then
		sudo mkdir -p /var/www/html/cloudera/cm7/${CM_VER}
	fi
}

function repo_cm() {
# Setup CM repo form a local tarfile

	echo "Install CM repo"

	# Install CM repo from local  
	sudo tar -xvzf ${DIR}/lib/cm${CM_VER}-redhat7.tar.gz -C /var/www/html/cloudera/cm7 
	sudo chmod -R ugo+rX /var/www/html/cloudera/cm7
}

function restart_http() {
# Restart the HTTP service

	sudo systemctl restart httpd
}

function check_repo() {

	echo "Verify the repos at:"
	echo "http://cmhost.example.com:8064/cloudera"
}

# Main
# Checks
call_include
check_arg 1 

# Run
install_http
make_dir
repo_cm
restart_http
check_repo
