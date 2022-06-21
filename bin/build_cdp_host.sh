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

# Title: build_cdp_host.sh
# Author: WKD 
# Date: 210321 
# Purpose: This script configures a CentOS host for CDP.
# Run this script on a host or EC2 instance with CentOS 7 installed. 
# The $HOME/conf directory must be accessiable as it contains many 
# required configuration files. 

# Disclaimer: This script contains a set of recommendations for 
# a CentOS host supporting CDP. It is not definitive. All CDP admins
# should conduct their own research to further determine their
# requirements. Please comment out those functions and lines not
# required for your CDP host.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
NUMARGS=$#
DIR=${HOME}
LOGDIR=${DIR}/log
LOGFILE=${LOGDIR}/setup-cdp-host.log

# FUNCTIONS
function usage() {
# usage

	echo "Usage: $(basename $0)"
	exit 1
}

function check_sudo() {
# Testing for sudo access to root

        sudo ls /root > /dev/null 2>&1
        RESULT=$?
        if [ $RESULT -ne 0 ]; then
                echo "ERROR: You must have sudo to root to run this script"
                usage
        fi
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

function check_log_dir() {
# Check if the log dir exists if not make the log dir

        if [ ! -d "${LOGDIR}" ]; then
                mkdir ${LOGDIR}
        fi
}

function setup_log() {
# Check the existance of the log directory and setup the log file.

        check_log_dir

        echo "******LOG ENTRY FOR ${LOGFILE}******" >> ${LOGFILE}
        echo "" >> ${LOGFILE}
}

function yes_no() {
        WORD=$1

        while :; do
                echo -n "${WORD} (y/n)?  "
                read YES_NO junk

                case ${YES_NO} in
                        Y|y|YES|Yes|yes)
                                CODE_RETURN=0
                                break
                        ;;
                        N|n|NO|No|no)
                                CODE_RETURN=1
                                break
                        ;;
                        *)
                                echo "Enter y or n"
                        ;;
                esac
        done
}

function check_continue() {
# Check if answer is correct and then break from the loop

        if yes_no "Continue? "; then
                if [ "${CODE_RETURN}" -eq 1 ]; then
                        exit
                fi
        fi
}

function intro() {
# Intro remarks.

	echo "*** S E T U P   H O S T   F O R   C D P ***"
	echo
	echo "This script will configure a host to support CDP."
	echo "Once the script is completed and the host is validated"
	echo "this host should be used by the system admins as a gold image."
	echo "This script may also be used by a CDP admin to validate a host."
	echo
	echo "*** W A R N I N G  ***"
	echo "This script should not be run on a host where Cloudera Manager"
	echo -n "and/or a CDP Cluster is deployed. "
	check_continue
}

### OS CHECK
function check_os() {
# Check the release for CentOS

	echo
	echo "***CDP requires CentOS version 7.6, 7.7, 7.8, or 7.9."
	echo -n "The current verion is "
	cat /etc/centos-release
	echo "ACTION: If the OS version is incorrect exit and rebuild."
	checkExit
}

### INSTALLING PACKAGES
function set_epel() {
# Install epel repo for CentOS

	if [ -f /etc/yum.repos.d/epel.repo ]; then
		echo "The epel.repo file exists."
	else
		yesno "Install the epel repo file "
		ans=$?
		if [ $ans -eq 1 ]; then return 1; fi
		yum install -y epel-release
	fi
}

function install_jdk() {
# Install OpenJDK

	echo "***CDP requires either OpenJDK version 1.8 or Oracle JDK version 1.8"
	if [ -f /usr/java/default/bin/javac ]; then
		echo -n "OpenJDK is installed: "
		javac -version
		echo "ACTION: If JDK version is incorrect exit and rebuild."
	else
		yesno "Install OpenJDK 1.8 "
		ans=$?
		if [ $ans -eq 1 ]; then return 1; fi
		sudo yum install -y java-1.8.0-openjdk
		sudo yum install -y java-1.8.0-openjdk-devel
		sudo mkdir /user/java
		sudo ln -s /usr/lib/jvm/java /usr/java/default
		echo "JAVA_HOME will be /usr/java/default"
	fi
}

function install_python() {
# Install python 

	echo "***CDP requires Python version 2.7 or greater."
	if [ -f /usr/bin/python ]; then
		echo -n "Python is installed: "
		python --version
		echo "ACTION: If Python version is incorrect exit and rebuild."
	else
		yesno "Install Python 2.7 "
		ans=$?
		if [ $ans -eq 1 ]; then return 1; fi
        	sudo yum install -y python2.7-devel
        	sudo yum install -y python-pip \
		       	python-argparse \
        		python-configobj \
        		python-httplib2 
	fi
}

function install_tool() {
# Install common tools, this list is based on the premise the initial
# CentOS install was stripped down. Many of these packages may already
# be installed.

	echo "***CDP recommends installing common tools and commands."
	yesno "Install common packages "
	ans=$?
	if [ $ans -eq 1 ]; then return 1; fi
        sudo yum install -y ack \
			curl\
        		bzip2 \
        		chrony \
        		curl \
        		deltarpm \
        		emacs \
        		gedit \
        		git \
        		httpd \
        		file \
        		initscripts \
        		net-tools \
        		nss \
        		psmisc \
        		mosh \
        		nano \
        		openssl \
        		openssh-server \
        		openssh-clients \
			screen \
        		sudo \
        		tar \
        		tmux \
        		tzdata \
        		wget \
        		unzip \
        		vim \
        		zip
}

function install_security() {
# Install security packages, this is not required if you are using FreeIPA

	echo "***CDP, when using Active Directory, requires security packages."
	echo "If you are using FreeIPA do NOT install the security packages."
	yesno "Install Security packages "
	ans=$?
	if [ $ans -eq 1 ]; then return 1; fi
	sudo yum install -y adcli \
       			authconfig \
			bind \
        		bind-utils \
        		ca-certificates \
        		kkbind-utils \
        		krb5-workstation \
        		openldap-clients \
        		openssl
	echo
	echo "The sssd deamon must be configured for Active Directory."
	echo "ACTION: Configure and run the install-sssd-ad.sh script." 
}

function install_lib() {
# Install libraries

	echo "***CDP requires development libraries."
	yesno "Install library packages "
	ans=$?
	if [ $ans -eq 1 ]; then return 1; fi
	sudo yum install -y libxml2-devel 
}

### CONFIGURE THE HOST
function set_kernel() {
# Set swappiness to minimum level of 1 and disable Transparent Huge Page
# Disable transparent huge pages on reboot by appending to /etc/rc.d/rc.local

	echo "***CDP requires changes to the OS kernel."
	if [[ $(cat /proc/sys/vm/swappiness) = 1 ]]; then
		echo "Swappiness is set to 1."
	else	
		yesno "Set kernel parameters for swap "
		ans=$?
		if [ $ans -eq 1 ]; then return 1; fi
		sudo sysctl -w vm.swappiness=1
		sudo echo "vm.swappiness=1" >> /etc/sysctl.conf
	fi

	if [[ $(grep hugepage /etc/rc.d/rc.local) ]]; then
		echo "Transparent Hugepage is disabled."
	else
		yesno "Set kernel parameters for transparent huge pages "
		ans=$?
		if [ $ans -eq 1 ]; then return 1; fi
		sudo cp ${DIR}/conf/rc.local /etc/rc.d/rc.local
		sudo chmod 744 /etc/rc.d/rc.local
	fi
}

function setUlimit() {
# set ulimit to 10000

	echo "***CDP recommends setting the ulimit command to unlimited."
	if [[ $(ulimit) == "unlimited" ]]; then
		echo "Ulimit is unlimited."
		ans=$?
		if [ $ans -eq 1 ]; then return 1; fi
		sudo ulimit -u unlimited 
	fi
}

function set_random_number() {
# Install rng-tools in support of entropy

	echo "***CDP recommends installing a Random Number Generator."
	if systemctl -q is-active rngd ; then
		echo "The daemon rngd is running."
	else
		yesno "Install rng-tools "
		ans=$?
		if [ $ans -eq 1 ]; then return 1; fi
		sudo yum install -y rng-tools
		sudo systemctl enable rngd
		sudo systemctl start rngd
	fi
}

function set_ntp() {
# Set the Network Time Protocol. This is important for inter node 
# communications. 

	echo "***CDP requires ntpd."
	if systemctl -q is-active ntpd ; then
		echo "The daemon ntpd is running."
	else
		yesno "Install ntpd "
		ans=$?
		if [ $ans -eq 1 ]; then return 1; fi
		sudo yum install -y ntpd ntpdate
		sudo systemctl enable ntpd
		sudo systemctl start ntpd
	fi
}

function set_nscd() {
# Enable Name Service Caching (nscd) with only hostname caching 
# enabled for a 30-60 second period.

	echo "***CDP recommends installing nscd."
	if systemctl -q is-active nscd ; then
		echo "The daemon nscd is running."
	else
		yesno "Install nscd "
		ans=$?
		if [ $ans -eq 1 ]; then return 1; fi
		sudo yum install -y nscd
		sudo systemctl enable nscd
		sudo systemctl start nscd
	fi

# The sssd and nscd are not directly compatiable. It is
# important to make the following changes to the /etc/nscd.conf file.
# enable-cache passwd no
# enable-cache group no
# enable-cache host yes
# positive-time-to-live hosts 60
# negative-time-to-live hosts 20
	if [ -f ${DIR}/conf/nscd.conf ]; then
		sudo cp ${DIR}/conf/nscd.conf /etc/nscd.conf
	fi
}

function set_firewalld() {
# Turn off and disable firewalld. While it can be restarted after the 
# setup is complete, it is recommended firewalld is left off.

	echo "***CDP recommends not installing or disabling firewalld."
	if  ! systemctl -q is-active firewalld ; then
		echo "The daemon firewalld is not installed or is disabled."
	else 
		yesno "Disable firewalld "
		ans=$?
		if [ $ans -eq 1 ]; then return 1; fi
		sudo systemctl stop firewalld 
		sudo systemctl disable firewalld	
	fi
}

function set_selinux() {
# Cloudera will support SELinux; however, it is strongly recommended
# that SELinux is disabled. CDP security protocols reduce the requirement
# for SELinux.

	echo "***CDP requires SELinux be disabled during install."
	if [[ $(getenforce) == "Disabled" ]]; then
		echo "SELinux is disabled."
	else
		yesno "Disable SELinux "
		ans=$?
		if [ $ans -eq 1 ]; then return 1; fi
		sudo setenforce 0
		sudo sed -i 's/enforcing/disabled/' /etc/selinux/config 
	fi
}

function set_tune() {
# Disable the tune service

	echo "***CDP recommends not installing or disabling tuned."
	if ! systemctl -q is-active tuned ; then
		echo "The daemon tuned is not installed or is disabled."
	else 
		yesno "Disable tuned "
		ans=$?
		if [ $ans -eq 1 ]; then return 1; fi
		sudo systemctl start tuned
		sudo tuned-adm off
		sudo systemctl stop tuned
		sudo systemctl disable tuned
	fi
}

### CONFIGURE USERS
function config_root() {
# Lock the root password, there should be no ssh access either. 

	echo "***CDP recommends locking the root password."
	if [ -f /root/.bashrc ]; then
		echo "The root user is configured."
	else
		yesno "Configure the root user "
		ans=$?
		if [ $ans -eq 1 ]; then return 1; fi
		if [ -f ${DIR}/conf/bashrc ]; then
			sudo cp ${DIR}/conf/bash_profile /root/.bash_profile
			sudo cp ${DIR}/conf/bashrc /root/.bashrc
		fi
		echo "***Lock the root password"
		sudo passwd --lock root
	fi
}

function config_sudo() {
# Configure the sudoers directory file

	echo "***CDP recommends adding $JAVA_HOME to the sudoers file."
	if [[ $(grep "java/default/bin" /etc/sudoers) ]]; then
		echo "The /etc/sudoers file is correct."
	else 	
		yesno "Configure sudo file "
		ans=$?
		if [ $ans -eq 1 ]; then return 1; fi
		if [ -f ${DIR}/conf/sudoers ]; then
			sudo cp ${DIR}/conf/sudoers /etc/sudoers
		fi
	fi
}

function config_skel() {
# Configure the Skel file for users

	echo "***CDP recommends configuring /etc/skel for OS users."
	if [ -f /etc/skel/.bashrc ]; then
		echo "The /etc/skel directory is correct."
	else
		yesno "Configure the /etc/skel directory "
		ans=$?
		if [ $ans -eq 1 ]; then return 1; fi
		if [ -d ${DIR}/conf/skel ]; then
			sudo cp ${DIR}/conf/skel /etc/skel
		fi
	fi
}

function config_admin() {
# Setup the admin user $admin

	echo "***CDP recommends creating a local account for an admin user."
	echo -n "Enter the name of the admin user? "
	read ADMINUSER 
	
	if [ -f /home/${ADMINUSER}/.bashrc ]; then
		echo "The ${ADMINUSER} is configured."
	else
		yesno "Configure the admin user "
		ans=$?
		if [ $ans -eq 1 ]; then return 1; fi

		sudo useradd -G wheel ${ADMINUSER}

		if [ -f ${DIR}/conf/bashrc ]; then
			sudo cp ${DIR}/conf/bash_profile /home/${ADMINUSER}/.bash_profile
			sudo cp ${DIR}/conf/bashrc /home/${ADMINUSER}/.bashrc
		fi

		# setup public keys access 
		if [ ! -d /home/${ADMINUSER}/.ssh ]; then
			sudo mkdir /home/${ADMINUSER}/.ssh
			sudo chmod 700 /home/${ADMINUSER}/.ssh
		fi

		# Allow access to the admin user from the local host
		# This may be a security consideration for your environment
		if [ -f ${DIR}/conf/authorized_keys ]; then
			sudo cp ${DIR}/certs/authorized_keys /home/${ADMINUSR}/.ssh/authorized_keys
			sudo chmod 600 /home/${ADMINUSER}/.ssh/authorized_keys
		fi

		# change ownership
		sudo chown -R ${ADMINUSER}:${ADMINUSER} /home/${ADMINUSER} 
	fi
}

function update_yum() {
# Update packages and add additional packages as required. 

	echo "***CDP recommends updating all software."
	yesno "Update software with yum update "
	ans=$?
	if [ $ans -eq 1 ]; then return 1; fi
	sudo yum update && yum clean all
}

function validate_host() {
# Post the follow on instructions, primarily testing the success 
# of the build.
	echo
	echo "ACTION: Reboot the host and then validate the changes"
	echo "by running this script again."
}

# MAIN
# Run checks
check_sudo
check_arg 0 
check_file ${DIR}/conf/bashrc

#  Install software
intro
check_os
set_epel

#  Install software
install_jdk
install_python
install_tool
install_security
install_lib

# Setup environment 
set_kernel
set_random_number
set_ntp 
set_nscd
set_firewalld
set_selinux
set_tune

# Configure for users
#config_root
#config_sudo
#config_skel
#config_admin

# Validate 
update_yum
validate_host
