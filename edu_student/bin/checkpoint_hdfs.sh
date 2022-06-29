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

# Title: checkpoint_hdfs.sh
# Author: WKD
# Date: 1MAR18
# Purpose: This script check_points the NameNode. If the cluster has
# been offline for 24 hours a check point alert will be raised. It 
# will correct in time. Run this script as a CDP admin with superuser
# status to HDFS. The CDP admin requires a Kerberos TGT.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLE
NUMARGS=$#
DIR=${HOME}
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${DIR}/log/checkpoint-hdfs.log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0)"
        exit 
}

function call_include() {
# Test for script and run functions

        if [ -f ${DIR}/bin/include.sh ]; then
                source ${DIR}/bin//include.sh
        else
                echo "ERROR: The file ${DIR}/bin/include.sh not found."
                echo "This required file provides supporting functions."
		exit 1
        fi
}

function check_point() {
# Place NN in safemode and the merge editlogs into fsimage

	 hdfs dfsadmin -rollEdits
	 hdfs dfsadmin -safemode enter
	 hdfs dfsadmin -saveNamespace
	 hdfs dfsadmin -safemode leave
}

# MAIN
# Source Functions
call_include

# Run checks
check_tgt
check_sudo
check_arg 0

# Run checkpoint
check_point
