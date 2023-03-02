#!/bin/bash

# This script is for training purposes only and is to be used only
# in support of approved training. The author assumes no liability
# for use outside of a training environments. Unless required by
# applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.

# Title: tutorial-ssl.sh
# Author: WKD
# Date: 1MAR18
# Purpose: This file contains useful commands for openssl and keytool.
# This will assist students who are unfamiliar with these two complex
# and sophisticated commands to gain a basic understanding of their use.

# DEBUG
#set -x
#set -eu
#set >> /root/setvar.txt

# VARIABLE
NUMARGS=$#
DIR=${HOME}
DATETIME=$(date +%Y%m%d%H%M)
LOGFILE=${DIR}/log/tls-tutorial.log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0)"
        exit
}

function callInclude() {
# Test for script and run functions

        if [ -f ${DIR}/sbin/include.sh ]; then
                source ${DIR}/sbin/include.sh
        else
                echo "ERROR: The file ${DIR}/sbin/include.sh not found."
                echo "This required file provides supporting functions."
		exit 1
	fi
}

function heading() {

        echo ""
        echo "            T U T O R I A L   F O R   S S L "
        echo "---------------------------------------------------------------"
}

function showTLS() {
	clear
	heading
	echo "
Transport Layer Security (TLS)
 TLS is a security protocol for the network transport layer. It was
 purposely designed for the unique requirements of HTTP, i.e. for
 securing communications on the Internet. TLS uses Public-key
 cryptography. This is asymetrical encryption, meaning two different
 keys are required to encrypt or to decrypt communications. The primary
 purpose of TLS is to encrypt traffic between two points, preventing 
 a man in the middle attack. It is also commonly used for digital 
 signature. In both cases the private key is closely guarded and 
 the public key is broadly distributed. As both keys are required
 traffic can be encrypted by the private key and any number of 
 public key holders can decrypt. The public key holders have 
 certainity that the traffic was encyrpted by the holder of the
 private key. The same is true in reverse. In asymemetric key
 encryption scheme, anyone can encrypt traffic using the
 public key, but only the holder of the paired private key can
 decrypt. The private key has to be carefully guarded, while
 the public key can be freely distrubted. 

Public and Private Keys (.crt and .key)
 An unpredictable (meaning large and random) number is used to 
 generate an acceptable pair of keys suitable for use by an 
 asymmetric key algorithm. The private key has the bulk of 
 the encryption algorithm, typically containing either 1012 or 2024
 characters for the encryption algorithm. The private key is 
 identified with an file extension of .key. The public key
 contains fewer characters. The public key commonly has an
 extension of .crt. The two keys are referred to as a key pair
 for example:
   client.crt 	A public key contain the encyrption algorithm
   client.key	PEM formatted file contain the private key of the client
        "
        checkContinue
}

function showCA() {
	clear
	heading
	echo "
A private key is one half of the public/private key pair used in digital certificates. The private key is created before or during the time in which the Certificate Signing Request (CSR) is created. A CSR is a public key that is generated on a server or device according to the server software instructions. The CSR is required during the TLS certificate enrollment process because it validates the specific information about the web server and the organization. The CSR is submitted to a Certificate Authority (CA) which uses it to create a public key to match the private key without compromising the key itself.

The CA never has access to the private key. The private key remains on the server and is never shared. The public key is incorporated into the TLS certificate and shared with clients, which could be a browser, mobile device, or another server. Although the makeup of an TLS certificate consists of a private and public key, the TLS certificate itself is sometimes referred to as "the public key."  The TLS certificate is also referred to as the "end entity" certificate since it sits at the bottom of the certificate chain and is not used for signing/issuing other certificates.

Note: Do not confuse the servers private key with the session key. This is a symmetric key which is created by the browser when it connects to a server. Session keys are typically 128 or 256-bit. The size used depends on the encryption capability of the client and server. The symmetric key is used to encrypt and decrypt information sent back and forth during the TLS session

The 2048-bit TLS certificate and private key (server) is called an asymmetrical key pair.  This means that one key is used to encrypt data (the public key/TLS certificate) and the other is used to decrypt data (the private key stored on the server)."

        checkContinue
}

function showFormats() {

        clear
	heading
        echo "
		X.509 certificate encoding formats and extensions:

Base64 (ASCII)
	PEM

		.pem   Privacy Enhanced Mail (all of these keys are pem files) 
		.csr   certificate signing request
		.crt   certificate = signed public key
		.key   private key
		.ca-bundle

	PKCS#7
		.p7b
		.p7s

Binary
	DER

		.der
		.cer

	PKCS#12

		.pfx
		.p12

*.pem, *.crt, *.ca-bundle, *.cer, *.p7b, *.p7s files contain one or more X.509 digital certificate files that use base64 (ASCII) encoding. You get one of those in a zip file downloaded from your user account or receive such file from the Certificate Authority.
"
        checkContinue
}


function showCreateKey() {
        clear
	heading
        echo "
IMPORTANT: For tutorial purposes we use the password BadPass%1 throughout.

Create a Working Directory
	# Create a working director for this tutorial
	% mkdir tutorial
	% cd tutorial

Creating a Private Key
 The openssl tool can be used to also create private keys.

        # Create a private key, the output will be private.key
        % openssl genrsa -out private.key 2048

	# Check output
	% ls
		private.key

        # Verify the  private key
	% cat private.key
        % openssl rsa -check -in private.key
                -----BEGIN RSA PRIVATE KEY-----
                -----END RSA PRIVATE KEY-----

Creating a Public Key

	# Export a public key from the private key
	% openssl rsa -in private.key -outform PEM -pubout -out public.crt 

	# Check output
	% ls
		private.key  public.crt

	# Verify the public key
	% cat public.crt
                -----BEGIN PUBLIC KEY-----
                -----END PUBLIC KEY-----
        "
        checkContinue
}

function showCreateCSR() {
        clear
        heading
        echo "
Certificate (.crt or .cert) 
 A certificate is a special type of public key. It is a public key that
 contains additional information about the orgin of the key. The act
 of adding this information is called 'signing the key'. It takes
 several steps to sign the public key.

Certificate Signing Request (.csr) 
 Getting a public key signed requires a certificate signing request
 or a .csr. A command is issued to take a public key, to encode additional
 information such as the hostname or username, and to create a .csr
 file. This file is the certificate signing request. 

	 # Generate a domain CSR from an existing private key
         % openssl req -key private.key -new -out request.csr
               Generating a 2048 bit RSA private key
                ...............+++
                ..........................+++
                writing new private key to 'domain.key'
                Enter PEM pass phrase: BadPass%1
                Verifying - Enter PEM pass phrase: BadPass%1
                -----
                Country Name (2 letter code) []:US
                State or Province Name (full name) []:CA
                Locality Name (eg, city) []:Santa_Clara
                Organization Name (eg, company) []:Docker
                Organizational Unit Name (eg, section) []:EDU
                Common Name (eg, fully qualified host name) []:admin01.cloudair.lan
                Email Address []:wkd@cloudair.lan

                Please enter the following 'extra' attributes
                to be sent with your certificate request
                A challenge password []:BadPass%1

	# List the directory
	% ls
		private.key  public.crt  request.csr

	# Verify the content of the request.csr file
	% openssl req -text -noout -verify -in request.csr
      "
        checkContinue
}	

function showCA() {
        clear
        heading
        echo "
Certificate Authority (CA)
 Normally a certificate signing request is sent to a Certificate 
 Authority (CA). The CA is a well know, well established, and thus 
 trusted agency. Examples include Verisign and GoDaddy. They receive 
 the request.csr file and then sign this file with their own information.
 They produce the signed public key. This signed public key can 
 then be widely distributed. When a client uses this signed public key 
 they pull information from the key including the identification of the 
 CA. The client then contacts the CA and asks them to validate this 
 public key. The CA sends back a yes or no to the client and the client
 knows they can trust the orgins of the public key. There are a number
 of well recongized CA's on the Internet. Additionally, most enterprises 
 setup and use an internal CA. 

Certificates (.crt or .cert)
 The file that is returned from the CA is called a certificate. The 
 standard extension is either .crt or .cert. For example:
	certificate.crt

Self-Signed Certificates
 A standard work around to avoid having to send a .csr to a CA is 
 to create and use a self-signed certificate. Here the generating 
 authority is the same as the signing authority. For Internet
 purposes this is considered very unsecure. Self-signed certificates
 are generally used for testing, training, and development purposes. 
 If a CA-signed certificate is not required, you can issue a
 self-signed certificate. A self-signed certificate is signed
 with its own private key.

Enterprise CA
 Additionally, most enterprises setup and use an internal CA. This
 is what we will do for enabling TLS for HDP.
"
	checkContinue
}

function showCreateCA() {
        clear
        heading
        echo "
Creating a CA
 The first step is to create a private key for our CA.

         # Create a private key for the CA
         % openssl genrsa -out ca.key 2048
                Generating RSA private key, 2048 bit long modulus
                ......................+++
                .................+++
                e is 65537 (0x10001)

	# Check the output
        % ls
                ca.key private.key public.crt request.cst

 	# When you have the private key you can then create 
	# a CA certificate
        % openssl req -new -x509 -key ca.key -out ca.crt
                -----
                Country Name (2 letter code) [XX]:US
                State or Province Name (full name) []:CA
                Locality Name (eg, city) [Default City]:Santa_Clara
                Organization Name (eg, company) [Default Company Ltd]:Docker
                Organizational Unit Name (eg, section) []:EDU
                Common Name (eg, your name or your server's hostname) []:admin01.cloudair.lan
                Email Address []:wkd@cloudair.lan

	# Check the output
        % ls
                ca.crt ca.key private.key public.crt request.cst
"
	checkContinue
}

function showSignCrt() {
        clear
        heading
        echo "
Signing a Certificate
 Generate a self-signed certificate from an existing CA private key
 and a csr. The x509 means a self-signed cert.

	# Create a crt
        % openssl x509 -req -CA ca.crt -CAkey ca.key -in request.csr -out signed.crt -days 365 -CAcreateserial
                Signature ok
                subject=/C=US/ST=CA/L=Santa_Clara/O=Docker/OU=EDU/CN=ip-172-31-11-176.eu-central-1.compute.internal/emailAddress=wkd@cloudair.lan
                Getting CA Private Key

	# Check the output
        % ls
                ca.crt ca.key private.key public.crt request.cst signed.crt

	# Verify the crt
        % openssl x509 -text -noout -in signed.crt
        "
        checkContinue
}

function showVerify() {
        clear
	heading
        echo "
Verifying Keys and Certs
 The RSA key algorithm is a public-key encryption technology. View and 
 verify the components of TLS.

        # View a private key
        % openssl rsa -check -in private.key
                Enter pass phrase for private.key: BadPass%1
                RSA key ok
                writing RSA key
                -----BEGIN RSA PRIVATE KEY-----

	# View the certificate
        % openssl x509 -in signed.crt -noout -text
                Certficate:
                        Data:

	# Verify a private key
        % openssl rsa -noout -modulus -in private.key | openssl md5
                6c9cf8243ce2dc36acb8a198c783b82c

	# Verify a certificate signing request 
        % openssl req -noout -modulus -in request.csr | openssl md5
                6c9cf8243ce2dc36acb8a198c783b82c

	# Verify a certificate  
        % openssl x509 -noout -modulus -in signed.crt | openssl md5
                6c9cf8243ce2dc36acb8a198c783b82c
        "
        checkContinue
}

function showJKS() {
        clear
	heading
        echo "
Java Keystore
 When a large complex enterprise embraces TLS as a solution one result
 will be a large number of keys and certificates to manage. A large
 number of such files can become a management challenge. The Java
 commmunity create a solution called Java Keystores. As the name 
 implies the solution is intended to store a large number of keys in
 a single file, called a store. Thus we can manage a large number of 
 keys and certificates by managing a single store file.

Keystore (JKS)
 The keystore is a binary file that holds keys. It is commonly used to
 hold both public keys and private keys. It can hold keys from a variety
 of formats, the two most common being pem and pkcs. The keys held within
 the keystore are used to validate other hosts and services for the client.
 They are used during the handshake establishing an encrypted channel for 
 communications. 
   keystore     DB stores private keys, public keys, and certificates

Truststore (JKS)
 The truststore file is the same binary file. While it is the same file 
 format it has a different purpose. The truststore holds certificates
 from trusted CA's. The CA's certificates identifies the address of the 
 trusted CA's and this can be validated. Any certificate in the keystore 
 that is signed by a trusted CA in the truststore will also be trusted.
   truststore   DB stores trusted Certificate Authorities

Trust Chain
 The series of trusts is called a trust chain. The client confirms that 
 the public key is signed by a CA certificate in the truststore.  

Alias
 The keystores will hold a number of keys and certificates. It identifies
 each element with an alias. It is important to manage these alias as
 these are used to lookup the required key or certificate.
        "
        checkContinue
}

function showCreateJKS() {
        clear
        heading
        echo "
Creating a Keystore
 The keytool can create private keys within a keystore at the time 
 of creation. All keystores require a password for the keystore and
 a password for the key itself.

	# Generate key in a new keystore
        % keytool -genkey -keystore keystore.jks -keyalg RSA -alias domain -validity 365
                Enter keystore password:
                Re-enter new password:

                What is your first and last name?
                [Unknown]:  admin01.cloudair.lan
                What is the name of your organizational unit?
                [Unknown]:  EDU
                What is the name of your organization?
                [Unknown]:  Docker
                What is the name of your City or Locality?
                [Unknown]:  Santa_Clara
                What is the name of your State or Province?
                [Unknown]:  CA
                What is the two-letter country code for this unit?
                [Unknown]:  US
                Is CN=admin01.cloudair.lan, OU=EDU, O=Docker, L=Santa_Clara, ST=CA, C=US correct?
                [no]:  yes

                Enter key password for <domain>
                (RETURN if same as keystore password):
                Re-enter new password:
	
	# Check output
        % ls
		ca.crt  ca.srl      keystore.jks  public.crt   signed.crt
		ca.key  private.key   request.csr
"
        checkContinue
}

function showCsrJKS() {
        clear
	heading
        echo "
Generating a CSR from the Keystore
  Use the public key in the keystore to generate a csr.

        # Generate CSR for existing private key
        % keytool -certreq -keystore keystore.jks -alias domain -file domain.csr
		Enter keystore password:

	# Check output
        % ls
		ca.crt  ca.srl      keystore.jks  public.crt   signed.crt
		ca.key  domain.csr  private.key   request.csr
        "
        checkContinue
}

function showSignCSR() {
        clear
	heading
        echo "
Signing a CSR from the Keystore
 Use the openssl tool and the CA certificate to sign this certificate
 signing request.

	# Sign the csr	
        % openssl x509 -req -CA ca.crt -CAkey ca.key -in domain.csr -out domain.crt
                Signature ok
                subject=/C=US/ST=CA/L=Santa_Clara/O=Docker/OU=EDU/CN=ip-172-31-11-176.eu-central-1.compute.internal
                Getting CA Private Key

	# Check output
        % ls
		ca.crt  ca.srl      domain.csr    private.key  request.csr
		ca.key  domain.crt  keystore.jks  public.crt   signed.crt
        "
        checkContinue
}

function showImportJKS() {
        clear
	heading
        echo "
Importing into the Keystore
 Importing keys is an important step in managing a keystore. You must
 establish a chain of trust. The first key in the chain should come from
 the CA. Additionally keys from this point are called intermediate keys.

        # Import a CA cert
        % keytool -import -keystore keystore.jks -alias CARoot -file ca.crt
                Enter keystore password: BadPass%1
                Owner: EMAILADDRESS=wkd@cloudair.lan, CN=ip-172-31-11-176.eu-central-1.compute.internal, OU=EDU, O=Docker, L=Santa_Clara, ST=CA, C=US

                Trust this certificate? [no]:  yes
                Certificate was added to keystore

        # Import an intermediate key 
        % keytool -import -keystore keystore.jks -alias domain -file domain.crt
                Enter keystore password: BadPass%1
                Certificate reply was installed in keystore
        "
        checkContinue
}

function showListJKS() {
        clear
	heading
        echo "
Listing the Keystore
 All keystores should be validated by listing the content.

        # View the certificate information
        % keytool -printcert -file domain.crt
		Owner: CN=admin01.cloudair.lan, OU=EDU, O=Docker, L=Menlo, ST=CA, C=US
		Issuer: EMAILADDRESS=wkd@cloudair.lan, CN=admin01.cloudair.lan, OU=EDU, O=Docker, L=Menlo, ST=CA, C=US
		Serial number: a45b23a32e09688b

        # List keystore certificate fingerprints
        % keytool -list -keystore keystore.jks
                Enter keystore password: BadPass%1
                Keystore type: JKS
                Keystore provider: SUN

	# List the full content of the keystore
        % keytool -list -v -keystore keystore.jks
                Enter keystore password: BadPass%1
                Keystore type: JKS
                Keystore provider: SUN
        "
	checkcontinue
}

function showManageJKS() {
        clear
        heading
        echo "
Managing Keystores
 There are a number of keytool commands for manaing the 
 keystores.

       # Export the certificate
       % keytool -exportcert -keystore keystore.jks -alias domain -file domain.cert
		Enter keystore password:
		Certificate stored in file <domain.cert>

        # Change the keystore password
        % keytool -storepasswd -new NewPass#1 -keystore keystore.jks
		Enter keystore password:

        # Change the key password
        % keytool -keypasswd alias domain -keystore keystore.jks
		Enter keystore password:

        # Rename the alias
        % keytool -changealias -alias domain -destalias newdomain -keystore keystore.jks
		Enter keystore password:

        # Delete the alias
	# Do NOT execute this command
        % keytool -delete -alias newdomain -keystore keystore.jks
                Enter keystore password:

	# Delete a certificate
	% keytool -delete -alias newdomain -keystore keystore.jks
                Enter keystore password:


END OF TUTORIAL
"
}

# MAIN
# Source functions
callInclude

# Explain 
showTLS
showCA
showFormats

# Run openssl
showCreateKey
showCreateCSR
showCA
showCreateCA
showSignCrt
showVerify

# Run keytool
showJKS
showCreateJKS
showCsrJKS
showSignCSR
showImportJKS
showListJKS
showManageJKS
