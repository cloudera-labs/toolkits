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

# Title: setup-mariadb.sh
# Author: WKD 
# Date: 20 Apr 2020 
# Purpose: This is a build script to install and configure mariadb
# with the correct databases and access.
# Setup for either Mariadb 9.6 or 10

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
NUMARGS=$#
DIR=${HOME}
DATETIME=$(date +%Y%m%d%H%M)
db_user="root"
db_password=BadPass@1

# FUNCTIONS
function usage() {
# usage
	echo "Usage: sudo $(basename $0) [backup|build|install|restore]"
	echo "			backup - backup the databases"
	echo "			build - build test databases"
	echo "			install - install and configure Mariadb"
	echo "			restore - restore databases from /tmp"
	exit 1
}

function call_include() {
# Test for script and run functions

        if [ -f ${DIR}/bin/include.sh ]; then
                source ${DIR}/bin/include.sh
        else
                echo "ERROR: The file ${DIR}/bin/functions not found."
                echo "This required file provides supporting functions."
		exit 1
        fi
}

function install_mariadb() {
# Install software

	yum install -y mariadb-server
}

function config_mariadb() {
# Configure Mariadb

	# Make sure that NOBODY can access the server without a password
	sudo mysql -e "UPDATE mysql.user SET Password = PASSWORD('${db_password}') WHERE User = 'root'"
	# Kill the anonymous users
	sudo mysql -e "DROP USER IF EXISTS ''@'localhost'"
	# Because our hostname varies we'll use some Bash magic here.
	sudo mysql -e "DROP USER IF EXISTS ''@'$(hostname)'"
	# Kill off the demo database
	sudo mysql -e "DROP DATABASE IF EXISTS test"
}

function enable_mariadb() {
# Enable Mariadb

	systemctl enable mariadb.service
	systemctl restart mariadb.service
	systemctl status mariadb.service &>> /var/log/mariadb-startup.log
}

function create_staging() {
# Creating a databases and tables 

	# Creating database staging
	echo "Creating staging database..."
	sudo mysql -e "CREATE DATABASE IF NOT EXISTS staging"

	# Creating table tasks
	echo "Creating table tasks in staging database..."
	sudo mysql -e "use staging;CREATE TABLE IF NOT EXISTS tasks ( \
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
	sudo mysql -e "CREATE DATABASE IF NOT EXISTS production"

	# Creating table completed 
	echo "Creating table completed in production database..."
	echo "Creating table completed in production database..."
	sudo mysql -e "use production; CREATE TABLE IF NOT EXISTS completed ( \
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
	sudo mysql -e "$query1"
	sudo mysql -e "$query2"
	sudo mysql -e "$query3"
	sudo mysql -e "$query4"
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
	sudo mysql -e "$query_5"
	sudo mysql -e "$query_6"
	sudo mysql -e "$query_7"
	sudo mysql -e "$query_8"
	echo "Database named 'completed' populated with dummy data."
}

function create_user() {
# Creating users
 
	# Create staging_user
	echo "Creating staging_user and grant all permissions to staging database..."
	mysql -e "CREATE USER IF NOT EXISTS 'staging_user'@'localhost' IDENTIFIED BY 'password1'"
	mysql -e "GRANT ALL PRIVILEGES ON staging.* to 'staging_user'@'localhost'"

	# Creat production_user
	echo "Creating production_user and grant all permissions to production database..."
	mysql -e "CREATE USER IF NOT EXISTS 'production_user'@'localhost' IDENTIFIED BY 'password2'"
	mysql -e "GRANT ALL PRIVILEGES ON production.* to 'production_user'@'localhost'"
}

function flush_database() {
# Make our changes take effect

	sudo mysql -e "FLUSH PRIVILEGES"
}

function backup_mariadb() {
# Backup all databases

	# get all databases
	databases=$(sudo mysql -uroot -p${db_password} -sse "show databases")
 
	# Create an array and remove system databases
	declare -a dbs=($(echo $databases | sed -e 's/information_schema//g;s/mysql//g;s/performance_schema//g'))

	# Loop through an array and backup databases to separate file
	# repair
	mysqlcheck -u$db_user -p$db_password --auto-repair --check --all-databases
 
	# export databases
	for db in "${dbs[@]}"; do
   		mysqldump -u$db_user -p$db_password --databases $db > $db.sql
	done
 
	# export users and privileges
	mysqldump -u$db_user -p$db_password mysql user > users.sql
}

function restore_mariadb() {
# Restore the mariadb from backups

	# folder where dump files are copied
	directory="/tmp"
 
	# list all sql files in $directory
	files=$(find $directory -type f -name "*.sql")
 
	# put all sql files into $sql_dumps array
	declare -a sql_dumps=($files)
 
	# Users are dumped to users.sql file.
	for sql_dump in "${sql_dumps[@]}"; do
    		if [[ $sql_dump == *"users.sql"* ]]; then
       			# import users and privileges
       			sudo mysql -u$db_user -p$db_password mysql < $directory/users.sql
		else
        		# import databases
        		sudo mysql -u$db_user -p$db_password < $sql_dump
    		fi
	done
 
	# Apply changes
	sudo mysql -u$db_user -p$db_password -e "FLUSH PRIVILEGES"
}

function run_option() {
# Case statement for options.

        case "${OPTION}" in
                -h | --help)
                        usage
                        ;;
                backup)
                        check_arg 1	
			backup_mariadb
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
			install_mariadb
			config_mariadb
			enable_mariadb
                        ;;
                restore)
                        check_arg 1
			restore_mariadb
                        ;;
                run)
                        check_arg 2
                        run_script
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

# Review log file
echo "Review log file at ${LOGFILE}"
