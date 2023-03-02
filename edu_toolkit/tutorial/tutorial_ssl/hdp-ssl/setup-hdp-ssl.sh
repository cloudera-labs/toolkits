#!/bin/sh

# This script is for training purposes only and is to be used only
# in support of approved training. The author assumes no liability
# for use outside of a training environments. Unless required by
# applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.
#
# Title: setup-hdp-ssl.sh
# Author:  WKD
# Date: 190410
# Purpose: Master script for running generate-ssl.sh.

# DEBUG
# set -x
#set -eu
#set >> /root/setvar.txt

# VARIABLES
DIR=/tmp/hdp-ssl

# FUNCTIONS
function usage() {
        echo "Usage: sudo $(basename $0)"
        exit 2
}

function checkRoot() {
# Testing for sudo access to root

        if [ "$EUID" -ne 0 ]; then
                echo "ERROR: This script must be run as root" 
                usage
        fi
}

function runCACert() {
# Run the certificate generator for local authority and for Ranger

	./generate-hdp-ssl.sh GenerateCACert ./configs
}

function runKeystore() {
# Run the certificate generator for local authority and for Ranger

	./generate-hdp-ssl.sh GenerateKeystore ./configs
}

function runTruststore() {
# Run the certificate generator for local authority and for Ranger

	./generate-hdp-ssl.sh GenerateTruststore ./configs
}

function runJCEKS() {
# Run the certificate generator for local authority and for Ranger

	./generate-hdp-ssl.sh GenerateJCEKS ./configs
}

function runKeyPair() {
# Run the certificate generator for local authority and for Ranger

	./generate-hdp-ssl.sh GenerateKeyPair ./configs
}

function runRanger() {
# Run the certificate generator for local authority and for Ranger

	./generate-hdp-ssl.sh GenerateRanger ./configs
}

# MAIN
checkRoot
cd ${DIR}

# Run
runCACert
runKeystore
runTruststore
runJCEKS
runKeyPair
runRanger
