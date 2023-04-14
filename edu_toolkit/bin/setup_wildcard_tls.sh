#!/bin/bash

# Copyright 2023 Cloudera, Inc.
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

# Disclaimer: This script contains a set of recommendations for
# a CentOS host supporting CDP. It is not definitive. All CDP admins
# should conduct their own research to further determine their
# requirements. Please comment out those functions and lines not
# required for your CDP host.

# Title: setup_wildcard_tls.sh
# Author: WKD
# Date: 230121


# DEBUG
#set -x
#set -eu
#set -e # Any subsequent(*) commands which fail will cause the shell script to exit immediately
#set >> /tmp/setvar.txt

# VARIABLES
num_arg=$#
dir=${HOME}
logfile=${dir}/log/$(basename $0).log
#cm_file=/ca/intermediate/certs/intermediate.cert.pem
cm_file=/var/lib/cloudera-scm-agent/agent-cert/cm-auto-in_cluster_ca_cert.pem


# FUNCTIONS
function usage() {
# usage

    	echo "Usage: $(basename ${0}) -d <endpoint_host> -f <file prefix> -n <cluster_name> [ -s self sign | -c sign csr with default CA]" 1>&2
        exit
}

function get_help() {
# get help

cat << EOF
SYNOPSIS
        setup_wildcard_tls.sh -d <app_domain> -f <file prefix> -n <cluster_name> [ -s self sign | -c sign csr with default CA]" 1>&2

DESCRIPTION
	This tool will generate a signed certs file and a private key file.
	The tool requires the PvC ECS app_domain and a prefix name for the pem 
	files. The tool can generate a self-signed cert and a private key. 
	The tool can generate a certificate signed by a CA. The tool is 
	configured to  use Cloudera Manager Auto-TLS. But the tool may be 
	configured to use the Cloudera Deploy ca_server. When using -c option, 
	this tool must be run on the host where Cloudera Manager or Cloudera 
	Deploy ca_server is installed.

	-h)
		Help page
	-c)
		Sign the csr with the default CA
	-d)
		-d <endpoint_host>
	-f)
		-f <file_prefix>
	-n)
		-n <cluster_name>
	-s) 
		Sign with self_sign

EXAMPLE
	setup_wildcard_tls.sh -d apps.ecs-1.example.com -f ecs -c 

EOF
        exit
}

function call_include() {
# Calls include script to run functions

        if [ -f ${dir}/bin/include.sh ]; then
                source ${dir}/bin/include.sh
        else
                echo "ERROR: The file ./include.sh not found."
                echo "This required file provides supporting functions."
                exit 1
        fi
}

function check_args() {

	echo ${num_arg} Number of args

	if [ ${num_arg} -eq 0 ]; then
		usage
		exit 1
	fi
}

function log_info() {
    echo "INFO : ${1}" | tee -a ${logfile} 
}

function log_error() {
    echo "ERROR: ${1}" | tee -a ${logfile} 
}

function run_cmd() {
    cmd="bash -c \"$1\""
    log_info "Running command: ${cmd}"
    bash -c "${cmd}"
    exit_code=`echo $?`
    log_info "Exit code = $exit_code"
    return $exit_code
}

function move_certs() {
	# Make a pki directory ecs

	pki_ecs=/opt/cloudera/security/pki/${cluster_name}

	if [ ! -d ${pki_ecs} ]; then
		sudo mkdir -p ${pki_ecs} 
	fi

	run_cmd "sudo chmod 440 ${key_file}"
	run_cmd "sudo mv ${cert_file} ${pki_ecs}/"
	run_cmd "sudo mv ${key_file} ${pki_ecs}/"
	run_cmd "sudo chown -R cloudera-scm:cloudera-scm ${pki_ecs}"
}


function create_cnf() {
	# Create a minimal openssl format config file, to allow for SubjAltNames

  cat >${conf_file} <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = ${domain_name}
[v3_req]
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${domain_name}
DNS.2 = *.${domain_name}
EOF

  if [ ! -f ${conf_file} ]; then
    log_error "Conf file was not created at: ${conf_file}"
    log_error "Can not continue"
    exit 1
  fi

  log_info "CommonName = ${domain_name}"
  log_info "SubjectAltName DNS.1 = ${domain_name}"
  log_info "SubjectAltName DNS.2 = *.${domain_name}"
  log_info "Created openssl conf file: ${conf_file}"
}

function create_csr() {
    #Create a PrivateKey unencoded (no des) and a CertSigning requet

    run_cmd "openssl req -new -sha256 -days 730  -newkey RSA:2048 -nodes -keyout ${key_file} -out ${csr_file} -extensions v3_req -config ${conf_file}"

    #convert key format to older PKCS#1 RSAPrivateKey, for compat with BouncyCastle libraries in Hadoop, not really required for ECS
    run_cmd "openssl rsa -in ${key_file} -out ${key_file}"

    log_info "Private key created: ${key_file}"
    log_info "Certificate Signing Request created: ${csr_file}"
}

function create_self_signed_cert() {
    #Create a PrivateKey unencoded (no des) and a SelfSigned Cert

    run_cmd "openssl req -x509 -sha256 -days 730 -newkey RSA:2048 -outform PEM -nodes -keyout ${key_file} -out ${cert_file} -extensions v3_req -config ${conf_file}"
    
    #convert key format to older PKCS#1 RSAPrivateKey, for compat with BouncyCastle libraries in Hadoop, not really required for ECS
    run_cmd "openssl rsa -in ${key_file} -out ${key_file}"

    log_info "Private key created: ${key_file}"
    log_info "Self Signed Certificate created: ${cert_file}"
}

function set_cacerts() {
	# Set the variables for ssl by pulling from the ssl-client.xml file.

    ssl_client=/etc/hadoop/conf/ssl-client.xml
    truststore_location=$(xmllint --xpath "//configuration/property[name='ssl.client.truststore.location']/value/text()" ${ssl_client})
	auto_tls_password=$(xmllint --xpath "//configuration/property[name='ssl.client.truststore.password']/value/text()" ${ssl_client})
}

function sign_csr() {
    # Sign the certificate using default CA, the def CA requires sudo for now

	set_cacerts
	
	run_cmd "sudo openssl x509 -req -CAkey ${ca_key} -CA ${ca_crt} -in ${csr_file} -out ${cert_file} -days 365 -CAcreateserial -passin pass:${auto_tls_password}"

#    run_cmd "sudo openssl ca -batch -config ${ca_conf} -in ${csr_file} -out ${cert_file} -notext -extensions v3_req -extfile ${conf_file} -passin pass:${auto_tls_password}"

    log_info "A CSR request was signed by default CA"
    log_info "Signed cert is: ${cert_file}"

    #Append the Intermediate CA Public Cert to the new cert
   # run_cmd "sudo cat ${cm_file} | sudo tee -a ${cert_file} > /dev/null"

    # Cleanup
    run_cmd "rm ${csr_file}"
}

function run_option() {
	# Run getopts on the command line options

	while getopts hd:f:n:cs option; do
		case ${option} in
			h) # display Help
				get_help
				exit
				;;
			d) #app domain
				domain_name="${OPTARG}"
				;;
			f) #file names from prefix
				prefix="${OPTARG}"
				;;
			n) #cluster name
				cluster_name="${OPTARG}"
				;;
			c) #-c flag sent
				ca_sign=true
				;;
			s) #-s flag sent
				self_sign=true
				;;
			:)
				log_error "${OPTARG} requires an argument."
				usage
				exit 1
				;;
			*) #unknown option
				usage
				exit 1
				;;
		esac
	done

	if [ -z "$domain_name" ] || [ -z "$prefix" ]; then
		log_error "Missing a required option: App Domain = \"${domain_name}\" File Prefix = \"${prefix}\""
		usage
		exit 1
	fi
}

function run_wildcard() {
	# Wildcard TLS program

	ca_sign=false
	self_sign=false

	run_option "$@"

	# Set prefix on files
	conf_file="${prefix}.cnf"
	csr_file="${prefix}.csr"
	key_file="${prefix}.key"
	cert_file="${prefix}.crt"
  
	#CA info hard coded for now, assumes CM CA with Auto-TLS
	ca_path="/var/lib/cloudera-scm-agent/agent-cert"
	ca_key=${ca_path}/cm-auto-host_key.pem
	ca_crt=${ca_path}/cm-auto-in_cluster_ca_cert.pem
	ca_conf="${ca_path}/openssl.cnf"

	log_info "App Domain  = \"${domain_name}\""
	log_info "Config File = \"${conf_file}\""
	log_info "Cert Sign Req file  = \"${csr_file}\""
	log_info "Private Key File = \"${key_file}\""
	log_info "Will sign csr with default CA:  \"${sign}\""

	if [ "${sign}" =  true ]; then
		log_info "Signed Cert File = \"${cert_file}\""
		log_info "Default CA = \"${ca_conf}\""
	fi

	if [ ${#domain_name} -lt 64 ]; then
		log_info "Using the app_domain name as-is: $domain_name";
		log_info ""
	else
		log_error "App Domain name is too long, must be less than 64 chars"
		exit 1;
	fi

	create_cnf
	log_info "create_cnf: DONE"
  
	if [ "${self_sign}" = false ]; then
		create_csr
		log_info "create_csr: DONE"
	fi

	if [ "${ca_sign}" =  true ]; then
		if [ $(sudo ls ${ca_conf} | grep -ic '^.*$' ) -eq 0 ]; then
			log_error "CA's config file does not exist: ${ca_conf}"
			log_error "This default CA requires you to have sudo rights"
			log_error "Can not continue"
			exit 1
		fi
		if [ $(sudo grep -ic "CN=${domain_name}" ${ca_path}/index.txt) -ne 0 ]; then
			log_error "An active cert already exists: CN=${domain_name}"
			log_error "Revoke the old cert or remove it from the CA db file"
			log_error "CA db file: ${ca_path}/index.txt"
			log_error "Can not sign the CSR"
			exit 1
		fi

		sign_csr
		log_info "sign_csr: DONE"
	fi

	if [ "${self_sign}" =  true ]; then
		create_self_signed_cert
		log_info "self_signed_cert: DONE"
	fi

	# Cleanup
	run_cmd "rm ${conf_file}"
	move_certs
	log_info "Move ${key_file} and ${cert_file} to ${pki_ecs}"
}

function main() {
        # Run checks
        call_include
        check_args
        check_sudo
		setup_log

        # Run command
		run_wildcard "$@"

        # Review log file
        echo "Review log file at ${logfile}"
}

# MAIN
main "$@"
exit

