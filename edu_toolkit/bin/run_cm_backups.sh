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

# Title: run_cm_backup.sh
# Author: WKD
# Date: 17MAR22
# Purpose: Run backups. This is required on a scheduled basis and prior 
# to an upgrade.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLE
num_arg=$#
dir=${HOME}
date_now=$(date +%y%m%d)
backup_name=cdp_7.1.7
db_password=BadPass@1
host_file=${dir}/conf/list_host.txt
option=$1
logfile=${dir}/log/run_cm_backup.log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [OPTION]"
        exit
}

function get_help() {
# Help page

cat << EOF
SYNOPSIS
        run_cm_backup.sh [OPTION]

DESCRIPTION
        This runs backups for CM, databases, hdfs, and hue.
	Run the --cm option to backup everything in one command.

        -h, --help
                help page
        -a, --agents
		Backup all CM agents 
	-c, --cm
		Backup agents, databases, hdfs, and hue
        -d, --databases
                Backup all CM and CDP datatabases
        -f, --hdfs
		Backup HDFS
	-s, --stop
		Stop the Cloudera Manager server
	-u, --hue
		Backup Hue
INSTRUCTIONS
	1. Always stop Cloudera Manager first
		run_cm_backups.sh -s
	2. Select the type of backup and run it.
		run_cm_backups.sh -c
	3. Verify the backup directories
		ls cdp_N.N.N_YYMMDD
		ls db	
EOF
        exit
}

function call_include() {
# Test for include script.

        if [ -f ${dir}/bin/include.sh ]; then
                source ${dir}/bin//include.sh
        else
                echo "ERROR: The file ${dir}/bin/include.sh not found."
                echo "This required file provides supporting functions."
                exit 1
        fi
}

function setup_log() {
# Open the log file

	exec 2> ${logfile}
	echo "---- Starting backup script for CM and CDP Runtime"
	echo "---- Disregard tar warnings below --------"
}

function make_dir() {
# Make backup directory

	export backup_dir="${backup_name}_${date_now}"
	if [ ! -d ${dir}/${backup_dir} ]; then
		mkdir -p ${dir}/${backup_dir}
	fi
}

function stop_cm() {
# Stop CM

	echo "-- Shutting down Cloudera Manager on cmhost"
	sudo systemctl stop cloudera-scm-server
}

function backup_server() {
# Backup the CM server

  	echo "---- Backing up Cloudera Manager Server"
	sudo -E tar -cf ${backup_dir}/cloudera-scm-server_${date_now}.tar /etc/cloudera-scm-server /etc/default/cloudera-scm-server
	sudo -E tar -cf $backup_dir/repository_server_${date_now}.tar /etc/yum.repos.d

}

function backup_services() {
# Backup Cloudera Management Services

	sudo cp -rp /var/lib/cloudera-host-monitor /var/lib/cloudera-host-monitor-${date_now}
	sudo cp -rp /var/lib/cloudera-service-monitor /var/lib/cloudera-service-monitor-${date_now}
	sudo cp -rp /var/lib/cloudera-scm-eventserver /var/lib/cloudera-scm-eventserver-${date_now}
}

function backup_db() {
# Back up CDH databases

	echo "---- Backing up MySQL databases hue and metastore"
	if [ ! -d ${dir}/db ]; then
		mkdir ${dir}/db
	fi
	mysqldump -uroot -p${db_password} --databases scm hue metastore > ${dir}/db/mysql_db_backup_${date_now}.sql
}

function backup_zookeeper() {
# Back up zookeeper data

	echo "---- Backing up zookeeper directories"
	ssh -tt master-1.example.com sudo cp -rp /var/lib/zookeeper/ /var/lib/zookeeper_backup_${date_now}
	ssh -tt master-2.example.com sudo cp -rp /var/lib/zookeeper/ /var/lib/zookeeper_backup_${date_now}
	ssh -tt master-3.example.com sudo cp -rp /var/lib/zookeeper/ /var/lib/zookeeper_backup_${date_now}
}

function backup_journal() {
# Back up Journal Node data

	echo "---- Backing up Journal Node" 
	echo "---- Note that these commands are expected to fail if HDFS is not configured for high availability"
	ssh -tt master-1.example.com sudo cp -rp /dfs/jn /dfs/jn_backup_${date_now}
	ssh -tt master-2.example.com sudo cp -rp /dfs/jn /dfs/jn_backup_${date_now} 
	ssh -tt master-3.example.com sudo cp -rp /dfs/jn /dfs/jn_backup_${date_now}
}

function backup_namenode() {
# Create backup directories on all NameNode hosts

	nn_list="master-1.example.com"

	echo "---- Creating NameNode backup directories"
	for host in $(echo ${nn_list}); do
		ssh -tt ${host} sudo mkdir -p /etc/hadoop/namenode_backup_${date_now}
		nn_dir=$(ssh -tt ${host} sudo "ls -t1 /var/run/cloudera-scm-agent/process | grep -e "NAMENODE\$" | head -1")
		nn_dir="${nn_dir%%[[:cntrl:]]}"
		ssh -tt ${host} sudo cp -rpf /var/run/cloudera-scm-agent/process/${nn_dir} /etc/hadoop/namenode_backup_${date_now}
		ssh -tt ${host} sudo rm /etc/hadoop/namenode_backup_${date_now}/${nn_dir}/log4j.properties
	done
}

function backup_datanode() {
# Create backup directories on all DataNode hosts

	dn_list="worker-1.example.com worker-2.example.com worker-3.example.com worker-4.example.com"

	echo "---- Creating DataNode backup directories"
	for host in $(echo ${dn_list}); do
		ssh -tt ${host} sudo mkdir -p /etc/hadoop/datanode_backup_${date_now}
		dn_dir=$(ssh -tt ${host} sudo "ls -t1 /var/run/cloudera-scm-agent/process | grep -e "DATANODE\$" | head -1")
		dn_dir="${dn_dir%%[[:cntrl:]]}"
		ssh -tt ${host} sudo cp -rpf /var/run/cloudera-scm-agent/process/${dn_dir} /etc/hadoop/datanode_backup_${date_now}
		ssh -tt ${host} sudo cp -pf /etc/hadoop/conf/log4j.properties /etc/hadoop/datanode_backup_${date_now}/${dn_dir}/
	done
}

function backup_agent() {
# Back up CM agents

	echo "---- Saving agent files and yum repos"
	for host in $(cat ${host_file}); do
		ssh -tt ${host} sudo -E tar -cf ${dir}/$backup_dir/${host}_agent_${date_now}.tar --exclude=*.sock /etc/cloudera-scm-agent /etc/default/cloudera-scm-agent /var/run/cloudera-scm-agent /var/lib/cloudera-scm-agent
		ssh -tt ${host} sudo -E tar -cf ${dir}/$backup_dir/${host}_repository_${date_now}.tar /etc/yum.repos.d
	done
}

function backup_hue() {
# Back up Hue Server registry file on cmhost

	hue_list="edge.example.com"

	echo "---- Backing up Hue Server registry filet"
	for host in $(echo ${hue_list}); do
		ssh -tt ${host} sudo mkdir -p /opt/cloudera/parcels_backup/
		ssh -tt ${host} sudo cp -p /opt/cloudera/parcels/CDH/lib/hue/app.reg /opt/cloudera/parcels_backup/app.reg-${backup_file}
	done
}

function msg_backup() {

	echo "---- Backup is complete."
	echo "---- The backup log file has been generated."
	echo "---- Ignore the backup errors from the tar command."
	# Review log file
	echo "Review log file at ${logfile}"
	echo "---- Cloudera Manager and the cluster are ready for upgrade."
}

function run_option() {
# Case statement for options.

    case "${option}" in
	-h | --help)
		get_help
		;;
	-a | --agent)
		check_arg 1	
		backup_agent
		;;
	-c | --cm)
		check_arg 1
		backup_db
		backup_server
		backup_services
		backup_zookeeper
#		backup_journal
		backup_namenode
		backup_datanode
		backup_agent
		backup_hue
		msg_backup
		;;
	-d | --databases)
		check_arg 1
		backup_db
		;;
	-f | --hdfs)
		check_arg 1
		backup_zookeeper
#		backup_journal
		backup_namenode
		backup_datanode
		;;
	-s | --stop)
		check_arg 1
		stop_cm
		;;
	-u | --hue)
		check_arg 1
		backup_hue
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
	setup_log

	# Setup
	make_dir	

	# Run command
	run_option

}

#MAIN
main "$@"
exit 0
