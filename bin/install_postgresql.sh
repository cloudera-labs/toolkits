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
db_user="root"
db_password=BadPass@1

# FUNCTIONS
function usage() {
# usage
        echo "Usage: sudo $(basename $0) [backup|build|install|restore]"
        echo "                  backup - backup the databases"
        echo "                  build - build test databases"
        echo "                  install - install and configure Mariadb"
        echo "                  restore - restore databases from /tmp"
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

function install_postgresql() {
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

function config_postgresql() {
# Two ways of configuring Postgres. The first is a fast work around.
# The second is configured to specific databases 

	check_file ${WRKDIR}/conf/custom_postgresql.conf
	cp ${WRKDIR}/conf/custom_postgresql.conf ${PGDATA}/postgresql.conf
	cp ${WRKDIR}/conf/custom_pg_hba.conf ${PGDATA}/pg_hba.conf
	chown postgresql:postgresql ${PGDATA}/postgresql.conf
	chown postgresql:postgresql ${PGDATA}/pg_hba.conf
}

function enable_postgresql() {
# Enable Postgresql

	systemctl enable postgresql-10.service
	systemctl restart postgresql-10.service
	systemctl status postgresql-10.service &>> /var/log/postgresql-startup.log
}


function create_staging() {
# Creating a databases and tables

        # Creating database staging
        echo "Creating staging database..."
        sudo pgsql postgres -c "CREATE DATABASE IF NOT EXISTS staging"

        # Creating table tasks
        echo "Creating table tasks in staging database..."
        sudo pgsql postgres -c "use staging;CREATE TABLE IF NOT EXISTS tasks ( \
                task_id INT AUTO_INCREMENT PRIMARY KEY, \
                title VARCHAR(255) NOT NULL, \
                start_date DATE, \
                due_date DATE, \
                status TINYINT NOT NULL, \
                priority TINYINT NOT NULL, \
                description TEXT \
        ) ENGINE=INNODB;" \
        echo "Table tasks created."
}

function create_production() {
# Creating a databases and tables

        # Creating database production
        echo "Creating production database..."
        sudo pgsql postgres -c "CREATE DATABASE IF NOT EXISTS production"

        # Creating table completed
        echo "Creating table completed in production database..."
        echo "Creating table completed in production database..."
        sudo pgsql postgres -c "use production; CREATE TABLE IF NOT EXISTS completed ( \
                task_id INT AUTO_INCREMENT PRIMARY KEY, \
                task_name VARCHAR(255) NOT NULL, \
                finished_date DATE, \
                status TEXT, \
                description TEXT \
        ) ENGINE=INNODB;" \
        echo "Table completed created."
}


function load_staging() {
# Load data into database staging

        # Loading data into task table
        echo "Inserting data into tasks table..."
        query1="use staging; INSERT INTO tasks (title, start_date, due_date, status, priority, description) \
        VALUES('task1', '2020-07-01', '2020-07-31', 1, 1, 'this is the first task')"
        query2="use staging; INSERT INTO tasks (title, start_date, due_date, status, priority, description) \
        VALUES('task2', '2020-08-01', '2020-08-31', 2, 2, 'this is the second task')"
        query3="use staging; INSERT INTO tasks (title, start_date, due_date, status, priority, description) \
        VALUES('task3', '2020-09-01', '2020-09-30', 1, 1, 'this is the third task')"
        query4="use staging; INSERT INTO tasks (title, start_date, due_date, status, priority, description) \
        VALUES('task4', '2020-10-01', '2020-10-31', 1, 1, 'this is fourth task')"
        sudo pgsql postgres -c "$query1"
        sudo pgsql postgres -c "$query2"
        sudo pgsql postgres -c "$query3"
        sudo pgsql postgres -c "$query4"
        echo "Database named 'staging' populated with dummy data."
}

function load_production() {
# Load data into production

        # Loading data into complete table
        echo "Creating table named 'completed' into production database..."
        query_5="use production; INSERT INTO completed (task_name, finished_date, status, description) \
                VALUES('task1', '2020-07-31','done', 'task one finished')"
        query_6="use production; INSERT INTO completed (task_name, finished_date, status, description) \
                VALUES('task2', '2020-08-31','completed', 'task two finished')"
        query_7="use production; INSERT INTO completed (task_name, finished_date, status, description) \
                VALUES('task3', '2020-09-30','done', 'task three finished')"
        query_8="use production; INSERT INTO completed (task_name, finished_date, status, description) \
                VALUES('task4', '2020-10-31','done', 'task four finished')"
        sudo pgsql postgres -c "$query_5"
        sudo pgsql postgres -c "$query_6"
        sudo pgsql postgres -c "$query_7"
        sudo pgsql postgres -c "$query_8"
        echo "Database named 'completed' populated with dummy data."
}

function create_user() {
# Creating users

        # Create staging_user
        echo "Creating staging_user and grant all permissions to staging database..."
        pgsql postgres -c "CREATE USER IF NOT EXISTS 'staging_user'@'localhost' IDENTIFIED BY 'password1'"
        pgsql postgres -c "GRANT ALL PRIVILEGES ON staging.* to 'staging_user'@'localhost'"

        # Creat production_user
        echo "Creating production_user and grant all permissions to production database..."
        pgsql postgres -c "CREATE USER IF NOT EXISTS 'production_user'@'localhost' IDENTIFIED BY 'password2'"
        pgsql postgres -c "GRANT ALL PRIVILEGES ON production.* to 'production_user'@'localhost'"
}

function flush_database() {
# Make our changes take effect

        sudo pgsql postgres -c "FLUSH PRIVILEGES"
}


function backup_postgresql() {
# Backup all databases

	echo "WIP"
}

function restore_postgresql() {
# Restore all databases

	echo "WIP"
}

function run_option() {
# Case statement for options.

        case "${OPTION}" in
                -h | --help)
                        usage
                        ;;
                backup)
                        check_arg 1
                        backup_postgresql
                        ;;
                build)
                        create_staging
                        create_production
                        load_staging
                        load_production
                        create_user
                        flush_database
                        ;;
                install)
                        check_arg 1
			install_postgresql
			config_file
			config_postgresql
			enable_postgresql
                        ;;
                restore)
                        check_arg 1
                        restore_postgresql
                        ;;
                *)
                        usage
                        ;;
        esac
}


# MAIN
# Run checks
call_include
check_sudo

# Run option
run_option

