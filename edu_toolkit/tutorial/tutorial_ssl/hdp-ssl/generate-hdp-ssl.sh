#!/bin/bash

# This script is for training purposes only and is to be used only
# in support of approved training. The author assumes no liability
# for use outside of a training environments. Unless required by
# applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.

# Title: generate-hdp-ssl.sh
# Author: WKD
# Date: 1MAR18
# Purpose: This script will generate the keystores and key pairs required
# to install SSL on a HDP cluster. This script needs to be locally run 
# on every node in the cluster. 
# There is a function to generate a creds.jceks file. This is intended 
# for use with the Knox Gateway. 
# The p12 key is to be used by the browser accessing NiFi.
# This environment requires the install of keytool, openssl, and rsync.

# Note: This script is built on work provided by Cloudera PS. It has
# been modified for classroom purposes.

# DEBUG
#set -x
#set -eu
#set >> /root/setvar.txt

# VARIABLES
NUMARGS=$#
DIR=$(pwd)
AUTHDIR=auth
CADIR=ca
KEYDIR=keys
OPTION=$1
CONFIG=$2
DATETIME=$(date +%Y%m%d%H%M)
LOGDIR=/var/log/hdp-ssl
LOGFILE=${LOGDIR}/generate-hdp-ssl.log

# FUNCTIONS 
function usage() {
# Usage
        echo -e "Usage: sudo $(basename $0) [OPTION] [CONFIG_FILE]\n     GenerateCSR: Run first to create a csr for the CA.\n     GenerateCACert: Update the cacerts file with the domain crt.\n     GenerateKeystore: Generate local host keystore.\n     GenerateTruststore: Generate local host truststore.\n     GenerateJCEKS: Generate the creds.jceks file.\n     GenerateKeyPair: Generate a crt, key, and p12 file.\n     GenerateRanger: Generate Ranger plugins keystore\n     GenerateKnox: Run only on the host for Knox."
	exit 1
}

function checkArg() {
# Check if arguments exits

        if [ ${NUMARGS} -ne "$1" ]; then
                usage
        fi
}

function checkRoot() {
# Testing for sudo access to root

        if [ "$EUID" -ne 0 ]; then
                echo "ERROR: This script must be run as root" | tee -a ${LOGFILE}
                usage
        fi
}

function logEntry() {
# Check if the log dir exists if not make the log dir

        if [ ! -d "${LOGDIR}" ]; then
                mkdir -p ${LOGDIR}
        fi
        echo "*** LOG ENTRY FOR  ${DATETIME} ***" >> ${LOGFILE}
}

function checkFile() {
# Check for a file

        FILE=$1
        if [ ! -f ${FILE} ]; then
                echo "ERROR: Input file ${FILE} not found" | tee -a ${LOGFILE}
                usage
        fi
}

function checkResult() {
# Testing for failed commands, exit script 

	RESULT=${1}

	if [ ${RESULT} -ne 0 ]; then
		echo "ERROR: Command failed" | tee -a ${LOGFILE}
		exit 1
	fi
} 

function checkConfig() {
# Check the config file is correct

	if [ -z ${CONFIG} ] && ! [ -s ${CONFIG} ]; then
		echo "ERROR Configs file does not exist, specify as first argument" | tee -a ${LOGFILE} 
		exit 1
	fi

	OU=$(cat ${CONFIG} | grep OrgUnit | cut -d "=" -f 2)
	if [ -z ${OU} ]; then
		echo "ERROR OrgUnit is not specified" | tee -a ${LOGFILE} 
		exit 1
	fi

	O=$(cat ${CONFIG} | grep Organization | cut -d "=" -f 2)
	if [ -z "${O}" ]; then
		echo "ERROR Organization is not specified" | tee -a ${LOGFILE} 
		exit 1
	fi

	L=$(cat ${CONFIG} | grep City | cut -d "=" -f 2)
	if [ -z ${L} ]; then
		echo "ERROR City is not specified" | tee -a ${LOGFILE} 
		exit 1
	fi

	S=$(cat ${CONFIG} | grep State | cut -d "=" -f 2)
	if [ -z ${S} ]; then
		echo "ERROR State is not specified" | tee -a ${LOGFILE} 
		exit 1
	fi

	C=$(cat ${CONFIG} | grep CountryCode | cut -d "=" -f 2)
	if [ -z ${C} ]; then
		echo "ERROR CountryCode is not specified" | tee -a ${LOGFILE} 
		exit 1
	fi

	DOMAIN=$(cat ${CONFIG} | grep Domain | cut -d "=" -f 2)
	if [ -z ${DOMAIN} ]; then
		echo "ERROR Domain is not specified" | tee -a ${LOGFILE} 
		exit 1
	fi

	PKILOC=$(cat ${CONFIG} | grep PkiLocation | cut -d "=" -f 2)
	if [ -z ${PKILOC} ]; then
		echo "ERROR PKI location is not specified" | tee -a ${LOGFILE} 
		exit 1
	fi

	KEYSTOREPASS=$(cat ${CONFIG} | grep KeystorePassword | cut -d "=" -f 2)
	if [ -z ${KEYSTOREPASS} ]; then
		echo "ERROR KeyStorePassword is not specified"  | tee -a ${LOGFILE} 
		exit 1
	fi

	KEYSTORELOC=$(cat ${CONFIG} | grep KeystoreLocation | cut -d "=" -f 2)
	if [ -z ${KEYSTORELOC} ]; then
		echo "ERROR KeyStoreLocation is not specified" | tee -a ${LOGFILE} 
		exit 1
	fi

	TRUSTSTOREPASS=$(cat ${CONFIG} | grep TruststorePassword | cut -d "=" -f 2)
	if [ -z ${TRUSTSTOREPASS} ]; then
		echo "ERROR TrustStorePassword is not specified" | tee -a ${LOGFILE}
		exit 1
	fi

	TRUSTSTORELOC=$(cat ${CONFIG} | grep TruststoreLocation | cut -d "=" -f 2)
	if [ -z ${TRUSTSTORELOC} ]; then 
		echo "ERROR TrustStoreLocation is not specified" | tee -a ${LOGFILE} 
		exit 1
	fi
}

function makeKeyDir() {
# Working directory to hold all keys

	if [ ! -d ${CADIR} ]; then
		mkdir -p ${CADIR}
	fi

	if [ ! -d ${KEYDIR} ]; then
		mkdir -p ${KEYDIR}
	fi
}

function makeSecurityDir() {
# Make directories for keys

	if [ ! -d ${PKILOC} ]; then
		mkdir -p ${PKILOC}
	fi

	if [ ! -d ${KEYSTORELOC} ]; then
		mkdir -p ${KEYSTORELOC} 
	fi

	if [ ! -d ${TRUSTSTORELOC} ]; then
		mkdir -p ${TRUSTSTORELOC}
	fi
}

function ChangePerm() {
# Prevent public access to the private key and keystores, this breaks 
# the startup as many service users must be able to access the 
# keystores.  

	if [ -f ${PKILOC}/server.key ]; then
		chmod 640 ${PKILOC}/server.key
	fi

	if [ -d ${KEYSTORELOC} ]; then
		chmod 750 ${KEYSTORELOC}
		chmod 640 ${KEYSTORELOC}/*jks
	fi
}

function setLocalHost() {
# Set variables for hostname and IP address for keystore 
# Set variables for naming the certs and keystore files 

	HNAME=$( hostname -f )
	HIP=$( hostname -i )
	HOST=$(hostname -f)
	LOCALHOST=$(echo $HOST | cut -d . -f 1)
	ALIAS=gateway-identity
	echo "Local Host ${LOCALHOST} is specified" | tee -a ${LOGFILE} 
}

function setRangerHost() {
# Set ranger hostname and IP address
# Set variables for naming the certs and keystore files 

        HNAME=$(cat ${CONFIG} | grep RangerHostname | cut -d "=" -f 2)
        if [ -z "${HNAME}" ]; then
                echo "ERROR Ranger Hostname is not specified" | tee -a ${LOGFILE}   
                exit 1
        fi

        HIP=$(cat ${CONFIG} | grep RangerIP | cut -d "=" -f 2)
        if [ -z "${HIP}" ]; then
                echo "ERROR Ranger IP Address is not specified" | tee -a ${LOGFILE} 
                exit 1
        fi

	HOST=${HNAME}
	LOCALHOST=ranger
	ALIAS=ranger.${DOMAIN}
}

function generateDomainCSR() {
# Use opensll to create a key pair for the CA. The output is a private
# key, .key, and an unsigned public key, .csr. Use the .csr to request a 
# signed public key from a CA.

	echo "Generate a public key csr to submit to the CA" | tee -a ${LOGFILE} 

	#openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
      	#-subj "/C=${C}/ST=${S}/L=${L}/O=${O}/CN=${DOMAIN}" \
      	#-keyout ${CADIR}/${DOMAIN}.key  -out ${CADIR}/${DOMAIN}.csr >> ${LOGFILE} 2>&1
	#RESULT=$?
	#checkResult ${RESULT}

# A P12 certificate with a signed key has already been downloaded into the auth 
# directory. All of the required file formats were then generated. This code copies
# these files into the ca directory. For more details see the auth/README file.

	checkFile ${AUTHDIR}/${DOMAIN}.crt

	cp ${AUTHDIR}/${DOMAIN}.crt ${CADIR}/${DOMAIN}.crt
	cp ${AUTHDIR}/${DOMAIN}.key ${CADIR}/${DOMAIN}.key
	cp ${AUTHDIR}/${DOMAIN}.der ${CADIR}/${DOMAIN}.der
}

function updateCACert() {
# Copy in the default CA keystore, cacerts. This file lists all approved CA's.
# Then use keytool to append the CA signed certificate into cacerts. This 
# adds a valid approval for our look ups, but these are still self-signed 
# certificates.

	echo "Import the CA x509 der into cacerts" | tee -a ${LOGFILE}  

	cp /usr/java/default/jre/lib/security/cacerts ${KEYDIR}/cacerts

 	keytool -importCert -noprompt -file ${CADIR}/${DOMAIN}.der \
	-keystore ${KEYDIR}/cacerts -alias ${DOMAIN} -storepass changeit >> ${LOGFILE} 2>&1
	RESULT=$?
	checkResult ${RESULT}
}

function checkCA() {
# Check if CA files have been generated

	checkFile ${CADIR}/${DOMAIN}.crt
}

function generateKeystore() {
# Use the keytool to generate a local host key pair, which is stored in 
# the local host keystore. These key files contains the hostname and the host IP. 
# The alias is gateway-identify, which is required by Knox Gateway.

	echo "Generate the ${LOCALHOST} keystore" | tee -a ${LOGFILE}  

	keytool -genkey -noprompt -alias ${ALIAS} -keyalg RSA \
	-dname "CN=$HOST, OU=${OU}, O=${O}, L=${L}, S=${S}, C=${C}"\
	-keystore ${KEYDIR}/${LOCALHOST}.jks -storepass "${KEYSTOREPASS}" -keypass "${KEYSTOREPASS}"\
	-ext SAN=DNS:"${HNAME}",IP:"${HIP}" >> ${LOGFILE} 2>&1
	RESULT=$?
	checkResult ${RESULT}
}

function generateLocalCSR() {
# Use the keytool to generate a request for signature (csr) for the local host.
# This output is directed to a host.csr file.

	echo "Generate the ${LOCALHOST} csr file" | tee -a ${LOGFILE}  

	keytool -certreq -noprompt -alias ${ALIAS} -keyalg RSA \
	-keystore ${KEYDIR}/${LOCALHOST}.jks -storepass "${KEYSTOREPASS}"  -keypass "${KEYSTOREPASS}" \
	-ext SAN=DNS:"${HNAME}",IP:"${HIP}" > ${KEYDIR}/${LOCALHOST}.csr 
	RESULT=$?
	checkResult ${RESULT}
}

function generateCRT() {
# Create a configuration file to contain the hostname and IP address. 
# Openssl takes an input request for signature as the host.csr file. 
# It then uses the domain.crt and the domain.key to sign this request. 
# The output is the host.crt. This is the signed public key.

	echo "Sign the ${LOCALHOST} csr file with the CA file and generate a crt" | tee -a ${LOGFILE}  

	# Create Extension file 
	echo "[ cert_extns ]" > ${KEYDIR}/cert_extn.conf
	echo "extendedKeyUsage = serverAuth,clientAuth" >> ${KEYDIR}/cert_extn.conf
	echo subjectAltName = DNS:\""${HNAME}"\",IP:\""${HIP}"\" >> ${KEYDIR}/cert_extn.conf

	# Sign the CSR	
	openssl x509 -req -extensions cert_extns -extfile ${KEYDIR}/cert_extn.conf \
	-in ${KEYDIR}/${LOCALHOST}.csr -CA ${CADIR}/${DOMAIN}.crt -CAkey ${CADIR}/${DOMAIN}.key \
	 -CAcreateserial -out ${KEYDIR}/${LOCALHOST}.crt -days 1024 -sha256 >> ${LOGFILE} 2>&1
	RESULT=$?
	checkResult ${RESULT}
}

function importCA() {
# Use keytool to import the signed CA key into the host keystore. 

	echo "Import CA der file into the keystore" | tee -a ${LOGFILE}  

	keytool -importCert -noprompt -file ${CADIR}/${DOMAIN}.der -alias ${DOMAIN}  \
	-keystore ${KEYDIR}/${LOCALHOST}.jks -storepass "${KEYSTOREPASS}" >> ${LOGFILE} 2>&1
	RESULT=$?
	checkResult ${RESULT}
}

function importCRT() {
# Use keytool to import the signed host key, host.crt, back into the host keystore.

	echo "Import ${LOCALHOST} signed crt file into the keystore" | tee -a ${LOGFILE}  

	keytool -importCert -noprompt -alias ${ALIAS} -file ${KEYDIR}/${LOCALHOST}.crt \
	-keystore ${KEYDIR}/${LOCALHOST}.jks -storepass "${KEYSTOREPASS}" >> ${LOGFILE} 2>&1
	RESULT=$?
	checkResult ${RESULT}
}

function generateTruststore() {
# Use the keytool to import the CA signed certificate and to create a truststore.

	echo "Generate the truststore" | tee -a ${LOGFILE}  

	keytool -importCert -noprompt -file ${CADIR}/${DOMAIN}.der -alias ${DOMAIN} \
	-keystore ${KEYDIR}/truststore.jks -storepass "${TRUSTSTOREPASS}" >> ${LOGFILE} 2>&1
	RESULT=$?
	checkResult ${RESULT}
}

function generateJCEKS() {
# Generate credential key  to securely store the password.

	echo "Generate the credential jceks file" | tee -a ${LOGFILE}  

  	hadoop credential create keystore.password -provider jceks://file/$(pwd)/${KEYDIR}/creds.jceks -value "${KEYSTOREPASS}" >> ${LOGFILE} 2>&1
  	hadoop credential create password -provider jceks://file/$(pwd)/${KEYDIR}/creds.jceks -value "${KEYSTOREPASS}" >> ${LOGFILE} 2>&1
  	hadoop credential create truststore.password -provider jceks://file/$(pwd)/${KEYDIR}/creds.jceks -value "${TRUSTSTOREPASS}" >> ${LOGFILE} 2>&1
	RESULT=$?
	checkResult ${RESULT}
}

function generateP12() {
# Use keytool to output from the host keystore to a pkcs12 format file.

	echo "Generate the ${LOCALHOST} PKCS12 file" | tee -a ${LOGFILE}  

	keytool -importkeystore -srckeystore ${KEYDIR}/${LOCALHOST}.jks \
	-srcstorepass "${KEYSTOREPASS}" -srckeypass "${KEYSTOREPASS}" -srcalias ${ALIAS}\
	-destkeystore ${KEYDIR}/${LOCALHOST}.p12 -deststoretype PKCS12 \
	-deststorepass "${KEYSTOREPASS}" -destkeypass "${KEYSTOREPASS}" >> ${LOGFILE} 2>&1
	RESULT=$?
	checkResult ${RESULT}
}

function generateKeyPair() {
# Use openssl to output from the p12 file to a key pair, the .crt and .key file.
 
	echo "Generate the ${LOCALHOST} crt file" | tee -a ${LOGFILE}  

	openssl pkcs12 -in ${KEYDIR}/${LOCALHOST}.p12 -passin pass:${KEYSTOREPASS} \
	-nokeys -out ${KEYDIR}/${LOCALHOST}.crt >> ${LOGFILE} 2>&1

	echo "Generate the ${LOCALHOST} key file" | tee -a ${LOGFILE}  

	openssl pkcs12 -in ${KEYDIR}/${LOCALHOST}.p12 -passin pass:${KEYSTOREPASS} \
	-passout pass:${KEYSTOREPASS} -nocerts -out ${KEYDIR}/${LOCALHOST}.keytmp

	openssl rsa -in ${KEYDIR}/${LOCALHOST}.keytmp -passin pass:${KEYSTOREPASS} \
	-out ${KEYDIR}/${LOCALHOST}.key >> ${LOGFILE} 2>&1
	RESULT=$?
	checkResult ${RESULT}

	rm -f ${KEYDIR}/${LOCALHOST}.keytmp
}

function generateKnox() {
# Generate a keystore for Knox. The Knox keystore is created during the installation. This
# function will generate a new keystore. This works as there will be no change to the
# master secret.

	KNOXDIR=/usr/hdp/current/knox-server/data/security/keystores
	PKIDIR=/etc/security/pki

	echo "Replace the Knox keystore" | tee -a ${LOGFILE}  

	if [ ! -d ${KNOXDIR}.org ]; then
		cp -r ${KNOXDIR} ${KNOXDIR}.org
	fi
	
	if [ -f ${KNOXDIR}/gateway.jks ]; then
		rm ${KNOXDIR}/gateway.jks
	fi	

	keytool -importkeystore -srckeystore /etc/security/pki/server.p12 -srcstoretype pkcs12 \
	-srcstorepass ${KEYSTOREPASS} \
	-destkeystore ${KNOXDIR}/gateway.jks -deststoretype jks -deststorepass ${KEYSTOREPASS} \
	-alias gateway-identity >> ${LOGFILE} 2>&1

	keytool -export -keystore ${KNOXDIR}/gateway.jks -alias gateway-identity -storepass BadPass%1 -file ${PKIDIR}/gateway.cer

	openssl x509 -inform der -in ${PKIDIR}/gateway.cer -out ${PKIDIR}/gateway.pem
}

function pushKeystore() {
# Copy keystore into the directory /etc/security/keystores

	echo "Push the keystore into production" | tee -a ${LOGFILE}  

	rsync -arP ${KEYDIR}/${LOCALHOST}.jks ${KEYSTORELOC}/server.jks > /dev/null
	rsync -arP ${KEYDIR}/cacerts /usr/java/default/jre/lib/security/cacerts > /dev/null
	rsync -arP ${KEYDIR}/cacerts /etc/pki/ca-trust/extracted/java/cacerts > /dev/null
	rsync -arP ${KEYDIR}/cacerts /etc/pki/java/cacerts > /dev/null
}

function pushTruststore() {
# Copy keys into directory /etc/security/certs

	echo "Push the truststore into production" | tee -a ${LOGFILE}  

	rsync -arP ${KEYDIR}/truststore.jks ${TRUSTSTORELOC}/truststore.jks > /dev/null
}

function pushJCEKS() {
# Copy keys into directory /etc/security/certs

	echo "Create a creds.jceks file for production use." | tee -a ${LOGFILE}  

	rsync -arP ${KEYDIR}/creds.jceks ${KEYSTORELOC}/creds.jceks > /dev/null
}

function pushKeyPair() {
# Copy keys pair into the directory /etc/security/pki

	echo "Push the key pair into production" | tee -a ${LOGFILE}  

	rsync -arP ${KEYDIR}/${LOCALHOST}.crt ${PKILOC}/server.crt > /dev/null
	rsync -arP ${KEYDIR}/${LOCALHOST}.key ${PKILOC}/server.key > /dev/null
	rsync -arP ${KEYDIR}/${LOCALHOST}.p12 ${PKILOC}/server.p12 > /dev/null
}

function pushRangerKeystore() {
# Copy Ranger keys

	echo "Push the Ranger keystores into production" | tee -a ${LOGFILE}  

	rsync -arP ${KEYDIR}/ranger.jks ${KEYSTORELOC}/ranger-plugin.jks > /dev/null
	rsync -arP ${KEYDIR}/truststore.jks ${TRUSTSTORELOC}/ranger-truststore.jks > /dev/null
}

function runOption() {
# Case statement for options

	case ${OPTION} in
		GenerateCSR)
			echo "Run GenerateCSR" | tee -a ${LOGFILE}  
			generateDomainCSR
			;;
		GenerateCACert)
			echo "Run GenerateCACert" | tee -a ${LOGFILE}  
			updateCACert
			;;
		GenerateKeystore)
			echo "Run GenerateKeystore" | tee -a ${LOGFILE}  
			checkCA
			setLocalHost
			generateKeystore
			generateLocalCSR
			generateCRT
			importCA
			importCRT
			pushKeystore
			#ChangePerm
			;;
		GenerateTruststore)
			echo "Run GenerateTruststore" | tee -a ${LOGFILE}  
			checkCA
			generateTruststore
			pushTruststore
			;;
		GenerateJCEKS)
			echo "Run GenerateJCEKS" | tee -a ${LOGFILE}  
			generateJCEKS
			pushJCEKS
			;;
		GenerateKeyPair)
			setLocalHost
			generateP12
			generateKeyPair
			pushKeyPair
			#ChangePerm
			;;
		GenerateRanger)
			echo "Run GenerateRanger" | tee -a ${LOGFILE}  
			checkCA
			setRangerHost
			generateKeystore
			generateLocalCSR
			generateCRT
			importCA
			importCRT
			pushRangerKeystore
			#ChangePerm
    			;;
		GenerateKnox)
			echo "Run GenerateKnox" | tee -a ${LOGFILE}  
			generateKnox
			;;
  		*)
			usage
    			;;
	esac
}

# MAIN
checkArg 2
checkRoot
logEntry

# Run setups
checkConfig
makeKeyDir
makeSecurityDir

# Run option
runOption

# Review log file
echo "Review log file at ${LOGFILE}"
