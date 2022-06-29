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

# Title: install_sssd_ad.sh
# Author: WKD
# Date: 1MAR18
# Purpose: Install and configure sssd for the support of OS connection
# to LDAP/AD. 
# Note: This script is intended to be run on the gold image when
# building a CentOS host for CDP. 

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
NUMARGS=$#
DIR=${HOME}
AD_USER="registersssd"
AD_DOMAIN="cloudmart.lan"
AD_DC="ad01.cloudmart.lan"
AD_ROOT="dc=cloudmart,dc=lan"
AD_OU="ou=HadoopNodes,${AD_ROOT}"
AD_REALM=CLOUDAIR.LAN
LOGFILE=${DIR}/log/install-sssd.log

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
                echo "ERROR: The file ${DIR}/bin/include.sh was not found."
                echo "This required file provides supporting functions."
                exit 1
        fi
}

function check_sudo() {
# Testing for sudo access to root

        sudo ls /root > /dev/null
        if [ "$?" != 0 ]; then
                echo "ERROR: You must have sudo to root to run this script"
                usage
        fi
}

function check_arg() {
# Check arguments exits

        if [ ${NUMARGS} -ne "$1" ]; then
                usage
        fi
}

function install_sssd() {
# Install sssd software

	# Install cache
	sudo yum makecache fast
	sudo yum -y -q install authconfig adcli

	# Install sssd
	sudo yum -y -q install sssd sssd-krb5 sssd-ad sssd-tools oddjob-mkhomedir
}

function ad_command() {
# Run adcli

	sudo adcli join -v \
	--domain-controller=${AD_DC} \
	--domain-ou="${AD_OU}" \
	--login-ccache="/tmp/krb5cc_0" \
	--login-user="${AD_USER}" \
	-v \
	--show-details
}

function setup_sssd() {
# Note: The master & data nodes only require nss. 
# Edge nodes require pam. Configure sssd.conf

	sudo tee /etc/sssd/sssd.conf > /dev/null <<EOF
[sssd]
services = nss, pam, ssh, autofs, pac
config_file_version = 2
domains = ${AD_REALM}
override_space = _

[domain/${AD_REALM}]
id_provider = ad
ad_server = ${AD_DC}
#ad_server = ad01, ad02, ad03
#ad_backup_server = ad-backup01, 02, 03
auth_provider = ad
chpass_provider = ad
access_provider = ad
enumerate = False
krb5_realm = ${AD_REALM}
ldap_schema = ad
ldap_id_mapping = True
cache_credentials = True
ldap_access_order = expire
ldap_account_expire_policy = ad
ldap_force_upper_case_realm = true

fallback_homedir = /home/%d/%u
default_shell = /bin/false
ldap_referrals = false

[nss]
memcache_timeout = 3600
override_shell = /bin/bash
EOF
}

function copy_sssd_conf() {
# This offers a choice for the configuration file. This
# function copies the file from the local etc directory instead
# of creating the function with EOF.

	sudo cp ${HOME}/conf/sssd.conf /etc/sssd/sssd.conf
}

function config_sssd() {
# Config sssd

	# Setup permissions on configuration files
	sudo chown root:root /etc/sssd/sssd.conf
	sudo chmod 0600 /etc/sssd/sssd.conf

	# Restart sssd
	sudo systemctl restart sssd

	# Setup chkconfig to ensure autostart of daemons
	sudo authconfig --enablesssd --enablesssdauth --enablemkhomedir --enablelocauthorize --update

	# Restart oddjobd
	sudo chkconfig oddjobd on
	sudo systemctl restart oddjobd 

	# Restart sssd
	sudo chkconfig sssd on
	sudo systemctl restart sssd
}


# MAIN
# Run checks
check_arg 0
check_sudo

# Install sssd
install_sssd
ad_command
setup_sssd
#copy_sssd_conf

# Config sssd
config_sssd
