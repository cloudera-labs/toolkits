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

# Title: install_postgresql.sh
# Author: WKD 
# Date: 20 Apr 2020 
# Purpose: This is a build script to install and configure postgresql
# with the correct databases and access.
# Setup for either Postgresql 9.6 or 10

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
NUMARGS=$#
WRKDIR=/usr/local
PGDATA=/var/lib/pgsql/10/data
DATETIME=$(date +%Y%m%d%H%M)

# FUNCTIONS
function usage() {
# usage
	echo "Usage: sudo $(basename $0)"
	exit 1
}

function call_include() {
# Test for script and run functions

        if [ -f ${WRKDIR}/bin/include.sh ]; then
                source ${WRKDIR}/bin/include.sh
        else
                echo "ERROR: The file ${WRKDIR}/bin/functions not found."
                echo "This required file provides supporting functions."
		exit 1
        fi
}

function install_postgres() {
# Install software

	# Pull in rpm for 9.6
	# RUN rpm -Uvh http://yum.postgresql.org/9.6/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
	# Pull in rpm for 10
	yum install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm

	# Yum install
	yum install -y postgresql10 postgresql10-server postgresql10-contrib postgresql10-libs 

	# Run DB init
	/usr/pgsql-10/bin/postgresql10-setup initdb
}

function config_file() {

	echo 'host all all 0.0.0.0/0 md5' >> ${PGDATA}/pg_hba.conf
	echo "listen_addresses = '*'" >> ${PGDATA}/postgresql.conf
}

function config_postgres() {
# Two ways of configuring Postgres. The first is a fast work around.
# The second is configured to specific databases 

	check_file ${WRKDIR}/conf/custom_postgresql.conf
	cp ${WRKDIR}/conf/custom_postgresql.conf ${PGDATA}/postgresql.conf
	cp ${WRKDIR}/conf/custom_pg_hba.conf ${PGDATA}/pg_hba.conf
	chown postgres:postgres ${PGDATA}/postgresql.conf
	chown postgres:postgres ${PGDATA}/pg_hba.conf
}

function enable_postgres() {
# Enable Postgresql

	systemctl enable postgresql-10.service
	systemctl restart postgresql-10.service
	systemctl status postgresql-10.service &>> /var/log/postgresql-startup.log
}

# MAIN

# Run checks
call_include
check_sudo
check_tgt

# Run option
install_postgres
config_file
config_postgres
enable_postgres
