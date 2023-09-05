#!/bin/bash

# Copyright 2022 Cloudera, Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
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

# Title: uninstall_ecs.sh
# Author: hcoyote, clevesque, & WKD
# Date: 20NOV22
# Purpose: This script will uninstall ECS. This script is depending on two 
# ECS scripts, rke2-killall.sh and rke2-uninstall.sh. These scripts are
# located in /opt/cloudera/parcels/ECS/bin.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
# Modify these values as appropriate for your local environment
num_arg=$#
dir=${HOME}
option=$1
input="${dir}/conf/list_ecs_host.txt"
sudo_user="training"
priv_key="${dir}/.ssh/admincourse.pem"
#docker_store='/tmp/docker'
docker_store='/docker/*'
local_store='/ecs/local-storage'
longhorn_store='/ecs/longhorn-storeage'

# FUNCTION
function usage() {
        echo "Usage: $(basename $0) [delete_registry, clean_file, clean_iptable reboot]"
        exit
}

function help() {
# Instructions for running this tool
cat << EOF

SYNOPSIS
	uninstall_ecs.sh [OPTION}

DESCRIPTION
	Tool for uninstalling ECS and ensuring the hosts are ready for a new install.

	-h, --help
		Help pages
	-d, --docker
		Uninstall docker
	-e, --ecs
		Clean the ECS file system
	-i, --iptable
		Clean the iptables
	-r, --reboot
		Reboot just the ECS cluster
	
INSTRUCTIONS 
	 1. Stop and terminate all virtual warehouses, virtual clusters, and virtual workspaces. 
	 2. Delete the Docker registry on ECS. Look up and provide the correct hostname for the location of the Docker Registry master. This will not remove a local Docker Registry.
	     uninstall_ecs.sh --docker
	 3. Return to Cloudera Manager Home to stop the ECS cluster.
	     Select ECS > Stop
	 4. Reboot the ECS hosts. This will clear all ECS processes.
	      uninstall_ecs.sh --reboot
	 5. Clean the supporting file system.
	      uninstall_ecs.sh --ecs
	 6. Return to Cloudera Manager Home to uninstall the Data Services cluster.
	      Select Data Services > Action > uninstall
	 7. Clean the IP tables
	      uninstall_ecs.sh --iptable
	 8. Reboot the hosts. This will return the ECS hosts to initial state.
	      uninstall_ecs.sh --reboot
EOF
	exit
}

function call_include() {
# Test for script and run functions

        if [ -f ${dir}/bin/include.sh ]; then
                source ${dir}/bin//include.sh
        else
                echo "ERROR: The file ${dir}/bin/include.sh not found."
                echo "This required file provides supporting functions."
        exit 1
        fi
}

function delete_registry() {
# Delete the docker registery

	while : ; do
		read -p "Enter the hostname of the ECS master: " ecs_master
		if yes_no "Is the hostname for ${ecs_master} correct? "; then
			break
		else
			echo 		
		fi
	done

	echo "Deleting the Docker registry on ${ecs_master}";
	ssh -i ${priv_key} -o StrictHostKeyChecking=no  ${sudo_user}@${ecs_master} "
		sudo /opt/cloudera/parcels/ECS/docker/docker container stop registry;
		sudo /opt/cloudera/parcels/ECS/docker/docker container rm -v registry;
		sudo /opt/cloudera/parcels/ECS/docker/docker image rm registry:2";

	echo "Docker registry on ${ecs_master} is deleted."
	echo "Run this option again if there are additionally Docker registrys."
}

function clean_file_system() {
# Remove the file system in support of ECS
# Work through the host list and ensure that RKE is dead 
# before uninstalling and cleaning up it's OS-level remnant 
#

    while read -r -u10 host; do
        echo 
        echo "****************"
        echo "Cleaning the file system on ${host}";
        ssh -i ${priv_key} -o StrictHostKeyChecking=no ${sudo_user}@${host} "
	    cd /opt/cloudera/parcels/ECS/bin; 
	    echo "Deleting Ranger Kubernetes"
            sudo ./rke2-killall.sh;
            sudo ./rke2-killall.sh;
            sudo ./rke2-uninstall.sh;
            sudo [ -d "/var/lib/rancher" ] && echo "ERROR: Directory /var/lib/rancher exists. rke2-uninstall.sh has failed!";
            sudo [ -d "/var/lib/kubelet" ] && echo "ERROR: Directory /var/lib/kubelet exists. rke2-uninstall.sh has failed!";
	    echo "Deleting Docker"
            sudo rm -rf /var/lib/docker_server;
	    sudo [ -d "/var/lib/docker_server" ] && echo "ERROR: Directory /var/lib/docker_server exists.";
            sudo rm -rf /etc/docker/certs.d;
	    sudo [ -d "/etc/docker/certs.d" ] && echo "ERROR: Directory /etc/docker/certs.d exists.";
            echo "Deleting Docker, local and longhorn storage";
            sudo rm -rf ${docker_store};
            sudo rm -rf ${local_store};
            sudo rm -rf ${longhorn_store};
	    echo "Deleting run time"
            sudo systemctl stop iscsid;
            #sudo yum -y erase iscsi-initiator-utils;
            sudo rm -rf /var/lib/iscsi;
            sudo rm -rf /etc/cni;
            sudo rm -f /run/longhorn-iscsi.lock;
            sudo rm -rf /run/k3s;
            sudo rm -rf /run/containerd;
            sudo rm -rf /var/lib/docker;
            sudo rm -rf /var/lib/docker*;
            sudo rm -rf /var/log/containers;
            sudo rm -rf /var/log/pods;
            sudo rm -rf /etc/rancher;
            sudo rm -rf /ecs;
            sudo rm -rf /docker;
            sudo rm -rf /var/lib/docker_server;
	    sudo rm -rf /var/lib/rancher/rke2/server/db/etcd
            sudo rm -rf /etc/docker;
        ";
    done 10< "${input}"
}

function clean_iptable() {
# Clean out the iptable

   echo
   echo "Cleaning up the IP Tables"

    while read -r -u10 host; do
        echo "Cleaning the IP Tables on ${host}";
        ssh -i ${priv_key} -o StrictHostKeyChecking=no ${sudo_user}@${host} "
	    cd /opt/cloudera/parcels/ECS/bin; 
            echo "Reset iptables to ACCEPT all, then flush and delete all other chains";
            declare -A chains=(
                [filter]=INPUT:FORWARD:OUTPUT
                [raw]=PREROUTING:OUTPUT
                [mangle]=PREROUTING:INPUT:FORWARD:OUTPUT:POSTROUTING
                [security]=INPUT:FORWARD:OUTPUT
                [nat]=PREROUTING:INPUT:OUTPUT:POSTROUTING
            )
            for table in "${!chains[@]}"; do
                echo "${chains[$table]}" | tr : $"\n" | while IFS= read -r; do
                    sudo iptables -t "$table" -P "$REPLY" ACCEPT
                done
                sudo iptables -t "$table" -F
                sudo iptables -t "$table" -X
            done;
            sudo /usr/sbin/ifconfig docker0 down;
            sudo /usr/sbin/ip link delete docker0;
            ";
    done 10< "${input}"
}

function reboot_ecs() {
# Reboot the ecs hosts

	while read -r -u10 host; do
		echo "Reboot ${host}"
		ssh -i ${priv_key} -o StrictHostKeyChecking=no ${sudo_user}@${host} "sudo reboot now";
	done 10< "${input}"
}

function msg_file_clean() {
# Message for clean_file_system

	echo "The file system is clean for:"
	for host in $(cat ${input}); do 
		echo " ${host}"
	done
}

function msg_iptable_clean() {
# Message for clean_file_system

	echo "The iptables are clean for:"
	for host in $(cat ${input}); do
		echo " ${host}"
	done
}

function run_option() {
# Case statement for options.

        case "${option}" in
                -h | --help)
                        help
                        ;;
               -d | --docker)
                        check_arg 1
			delete_registry                        
                        ;;
                -e | --ecs)
                        check_arg 1
                       	clean_file_system 
			msg_file_clean
                        ;;
                -i | --iptable)
                        check_arg 1
                       	clean_iptable 
			msg_iptable_clean
                        ;;
                -r | --reboot)
                        check_arg 1
                       	reboot_ecs 
                        ;;
                *)
                        usage
                        ;;
        esac
}

function main() {
	# Source Function
	call_include

	# Run Checks
	check_sudo
	check_file ${input}
	check_file ${priv_key}

	# Run 
	run_option

	# Review log file
	# echo "Review log file at ${LOGFILE}
}

# MAIN
main "$@"
exit
