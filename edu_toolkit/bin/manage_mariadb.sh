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

# Title: manage-mariadb.sh
# Author: WKD 
# Date: 20 Apr 2020 
# Purpose: This is a build script to install and configure mariadb
# with the correct databases and access. Set the version in the
# list of variables. The tool will also backup and restore the
# database. The tool adds TLS to the database server.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
num_arg=$#
option=$1
dir=${HOME}
host=cmhost.example.com
mariadb_pw=BadPass@1
db_user="root"
db_password=BadPass@1
logfile=${dir}/log/$(basename $0).log

# FUNCTIONS
function usage() {
# usage
	echo "Usage: $(basename $0) [OPTION]"
	exit 1
}

function get_help() {
# get help

cat << EOF
SYNOPSIS
    install_mariadb.sh [OPTION]

DESCRIPTION
	This tool provides management of Mariadb. 
	This is a build script to install and configure mariadb
	with the correct databases and access. Set the version 
	in the list of variables. The tool will also backup and 
	restore the database. The tool adds TLS to the database 
	server. The tool will create a test databases with users.

	-h, --help
		Help page
	-b, --backup
		Backup the databases
	-d, --delete
		Delete the /etc/my.cnf.d/ssl directory
		Copy over the /etc/my.cnf.d/server.cnf file with bak
	-e, --example 	
		Create the example staging and a production database.
	-i, --install
		Install and configure MariaDB
	-m, --import
		Import the MariaDB certificate into the truststore file
		for jks and for pem. It is recommended practice to push both
		of these files to every host in the cluster.
	-s, --show
		Show the status of the database 
		Runs the following commands:
			sudo systemctl restart mariadb
			mysql --user=root --password=mariadb_pw --ssl=true 
			-e "SHOW VARIABLES LIKE '%ssl%';"
			mysql --user=root --password=mariadb_pw --ssl=true 
			-e "status;"
	-r, --restore
		Restore databases from /tmp
	-t, --tls  
		Creates TLS self-signed certificates in /etc/my.cnf.d/ssl
		Adds the following lines in the /etc/my.cnf.d/server.cnf 
		file under the [mysqld] section:
			ssl-ca=/etc/my.cnf.d/ssl/ca.crt 
			ssl-crt=/etc/my.cnf.d/ssl/mariadb.crt 
			ssl-key=/etc/my.cnf.d/ssl/mariadb.key 
			bind-address=*
	-u | --uninstall
		Uninstall the database server

CAUTION
	The uninstall option also deletes PostFix dependencies. To 
	delete without breaking mail servers you must use the rpm
	method for removing Mariadb.

EXAMPLE
	Install and configure server and databases
	$ manage_mariadb.sh --install
	$ manage_mariadb.sh --create
	$ manage_mariadb.sh --show

	Configure TLS
	$ manage_mariadb.sh --tls
	$ manage_mariadb.sh --show

	Backup and restore databases
	$ manage_mariadb.sh --backup
	$ manage_mariadb.sh --restore

	Setup staging and production demos
	$ manage_mariadb.sh --demo
EOF
    exit
}

function call_include() {
# Test for script and run functions

        if [ -f ${dir}/bin/include.sh ]; then
                source ${dir}/bin/include.sh
        else
                echo "ERROR: The file ${dir}/bin/functions not found."
                echo "This required file provides supporting functions."
		exit 1
        fi
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

function install_mariadb() {
# Install software

	sudo yum-config-manager --enable mariadb
	sudo yum install -y mariadb-server 
}

function enable_mariadb() {
# Enable Mariadb

	sudo systemctl enable mariadb.service
	sudo systemctl restart mariadb.service
	sudo systemctl status mariadb.service &>> ${dir}/log/mariadb-startup.log
}

function config_mariadb() {
# Configure Mariadb

	# Make sure that NOBODY can access the server without a password
	sudo mysql -e "UPDATE mysql.user SET Password = password_var('${db_password}') WHERE User = 'root'"
	# Kill the anonymous users
	sudo mysql -e "DROP USER IF EXISTS ''@'localhost'"
	# Because our hostname varies we'll use some Bash magic here.
	sudo mysql -e "DROP USER IF EXISTS ''@'$(hostname)'"
	# Kill off the demo database
	sudo mysql -e "DROP DATABASE IF EXISTS test"
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

function generate_tls() {
# Generate the ssl pem files 

	sudo mkdir /etc/my.cnf.d/ssl/
	cd /etc/my.cnf.d/ssl/

	sudo openssl req -newkey rsa:2048 -x509 -nodes -keyout ca.key -out ca.crt -days 365 -subj "/C=US/ST=NY/L=New York/O=GlobalCA/OU=Sale/CN=www.globalca.com"

	sudo openssl genrsa -out mariadb.key 2048 -days 365
	sudo openssl req -new -key mariadb.key -out mariadb.csr -days 365 -subj "/C=US/ST=CA/L=Santa Clara/O=Cloudride/OU=Edu/CN=www.cloudride.com"

	sudo openssl x509 -req -CAkey ca.key -CA ca.crt -in mariadb.csr -out mariadb.crt -days 365 -CAcreateserial
}

function config_tls() {
# Editing and restarting mysql to setup TLS.

    sudo mv /etc/my.cnf.d/server.cnf /etc/my.cnf.d/server.cnf.bak
    sudo cp ${dir}/conf/server.cnf /etc/my.cnf.d/server.cnf
    sudo systemctl restart mariadb

}

function set_ssl() {
# Set the variables for ssl by pulling from the ssl-client.xml file.

    export ssl_client=/etc/hadoop/conf/ssl-client.xml
    export truststore_location=$(xmllint --xpath "//configuration/property[name='ssl.client.truststore.location']/value/text()" ${ssl_client})
    export truststore_password=$(xmllint --xpath "//configuration/property[name='ssl.client.truststore.password']/value/text()" ${ssl_client})

    export pem_location=/var/lib/cloudera-scm-agent/agent-cert/cm-auto-global_cacerts.pem
}

function import_ssl() {
# Import the MariaDB CA certificate into the truststore files for jks and pem.

	sudo keytool -importcert -alias mariadb -file /etc/my.cnf.d/ssl/ca.crt -keystore ${truststore_location} -storetype jks -noprompt -storepass $truststore_password

	sudo cat /etc/my.cnf.d/ssl/ca.crt >> ${pem_location} 
}

function delete_tls() {
# Glean back TLS

    sudo rm -r /etc/my.cnf.d/ssl
    sudo cp /etc/my.cnf.d/server.cnf.bak /etc/my.cnf.d/server.cnf
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

function show_mariadb() {
# Show the status of Mariadb

	systemctl status mariadb.service
    	mysql --user=root --password=${mariadb_pw} --ssl=true -e "SHOW VARIABLES LIKE '%ssl%';"
    	mysql --user=root --password=${mariadb_pw} --ssl=true -e "status;"
}

function uninstall_mariadb() {
# Delete Mariadb

	sudo systemctl stop mariadb
	sudo yum remove mariadb mariadb-server
	sudo rm -f /etc/my.cnf
	sudo rm -f /etc/my.cnf.rpmnew
	sudo rm -rf /etc/my.cnf.d
	sudo rm -rf /var/lib/mysql
	sudo rm -rf /usr/lib64/mysql
	sudo rm -rf /usr/share/mysql
	sudo rm -rf /var/log/mariadb

	sudo userdel -r mysql
}

function run_option() {
# Case statement for options.

	case "${option}" in
		-h | --help)
			check_arg 1	
			get_help 
			;;
		-b | --backup)
			check_arg 1	
			backup_mariadb
			;;
		-d | --delete)
			check_arg 1
			delete_tls
			;;
		-e | --example)
			check_arg 1
			create_staging
			create_production
			load_staging	
			load_production
			create_user
			flush_database
			;;
		-i | --install)
			check_arg 1
			install_mariadb
			enable_mariadb
			config_mariadb
			;;
		-m | --import)
			check_arg 1
			set_ssl
			import_ssl
			;;
		-r | --restore)
			check_arg 1
			restore_mariadb
			;;
		-s | --show)
			check_arg 1
			show_mariadb
			;;
		-t | --tls)
			check_arg 1
			generate_tls
			config_tls
			;;
		-u | --uninstall)
			check_arg 1
			uninstall_mariadb
			;;
		*)
			usage
			;;
	esac
}

function main() {

	# Run checks
	call_include
	check_sudo
	#setup_log

	# Run option
	run_option

	# Review log file
	#echo "Review log file at ${logfile}"
}

#MAIN
main "$@"
exit 0
