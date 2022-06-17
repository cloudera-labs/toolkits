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

# Title: template.sh
# Author: WKD
# Date: 17MAR22
# Purpose: Describe shell script. 

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLE
CONTENT=${HOME}/training_materials/security
DIR=${HOME}

# FUNCTIONS

function copy_file() {
# Describe function.

	sudo cp -R ${CONTENT}/* ${DIR}
	sudo chown -R training:training ${DIR}	
}

function cleanup_file() {
	
	rmdir Music
	rmdir Pictures
	rmdir Videos
}

# MAIN
copy_file
cleanup_file
