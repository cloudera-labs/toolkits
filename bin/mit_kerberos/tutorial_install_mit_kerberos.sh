INSTALLING KERBEROS

This installation is going to require 2 servers one acts as kerberos KDC server and the other machine is going to be client. Lets assume the FQDN's are (here cw.com is the domain name, make a note of the domain name here):

Kerberos KDC Server: infra01.cloudmart.lan
Kerberos Client: admin01.cloudmart.lan

IMPORTANT
Make sure that both systems have their hostnames properly set and both systems have the hostnames and IP addresses of both systems in /etc/hosts. Your server and client must be able to know the IP and hostname of the other system as well as themselves.

SETUP AND INSTALL NTP
	% yum -y install ntp
	% ntpdate 0.rhel.pool.ntp.org
	% systemctl start  ntpd.service
	% systemctl enable ntpd.service

RHEL 7 comes with systemd as the default service manager. Here is a handy guide for mapping service and chkconfig command here

PACKAGES REQUIRED
	KDC server package: krb5-server
	Admin package: krb5-libs
	Client package: krb5-workstation

CONFIGURATION FILES
	/var/kerberos/krb5kdc/kdc.conf
	/var/kerberos/krb5kdc/kadm5.acl
	/etc/krb5.conf

IMPORTANT PATHS
	KDC path: /var/kerberos/krb5kdc/

INSTALL THE KDC SERVER
	% sudo yum -y install krb5-server krb5-libs

REVIEW THE PRIMARY CONFIGURATION FILE
Primary configuration file is '/etc/krb5.conf':

Ensure the default realm is set your domain name in capital case
Sample '/etc/krb5.conf'

[libdefaults]
    default_realm = CLOUDAIR.LAN
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    forwardable = true
    udp_preference_limit = 1000000
    default_tkt_enctypes = des-cbc-md5 des-cbc-crc des3-cbc-sha1
    default_tgs_enctypes = des-cbc-md5 des-cbc-crc des3-cbc-sha1
    permitted_enctypes = des-cbc-md5 des-cbc-crc des3-cbc-sha1

[realms]
    CLOUDAIR.LAN = {
        kdc = infra01.cloudmart.lan:88
        admin_server = infra01.cloudmart.lan:749
        default_domain = cw.com
    }

[domain_realm]
    .cw.com = CLOUDAIR.LAN
     cw.com = CLOUDAIR.LAN

[logging]
    kdc = FILE:/var/log/krb5kdc.log
    admin_server = FILE:/var/log/kadmin.log
    default = FILE:/var/log/krb5lib.log
Adjust /var/kerberos/krb5kdc/kdc.conf on the KDC:

default_realm = CLOUDAIR.LAN

[kdcdefaults]
    v4_mode = nopreauth
    kdc_ports = 0

[realms]
    CLOUDAIR.LAN = {
        kdc_ports = 88
        admin_keytab = /etc/kadm5.keytab
        database_name = /var/kerberos/krb5kdc/principal
        acl_file = /var/kerberos/krb5kdc/kadm5.acl
        key_stash_file = /var/kerberos/krb5kdc/stash
        max_life = 10h 0m 0s
        max_renewable_life = 7d 0h 0m 0s
        master_key_type = des3-hmac-sha1
        supported_enctypes = arcfour-hmac:normal des3-hmac-sha1:normal des-cbc-crc:normal des:normal des:v4 des:norealm des:onlyrealm des:afs3
        default_principal_flags = +preauth
    }


ADJUST THE ACL ON THE KDC
Adjust /var/kerberos/krb5kdc/kadm5.acl on KDC
	% sudo vim /var/kerberos/krb5kdc/kadm5.acl
		*/admin@CLOUDAIR.LAN	    *

CREATE THE KDC DATABASE
Creating KDC database to hold our sensitive Kerberos data
Create the database and set a good password which you can remember. This command also stashes your password on the KDC so you don’t have to enter it each time you start the KDC:

	% sudo kdb5_util create -r CLOUDAIR.LAN -s

This command may take a while to complete based on the CPU power

CREATE ADMIN PRINCIPAL
Now on the KDC create a admin principal and also a test user (user1):

	[root@kdc ~]# kadmin.local
	kadmin.local:  addprinc kadmin/admin
	kadmin.local:  addprinc jwalters 
	kadmin.local:  ktadd -k /var/kerberos/krb5kdc/kadm5.keytab kadmin/admin
	kadmin.local:  ktadd -k /var/kerberos/krb5kdc/kadm5.keytab kadmin/changepw
	kadmin.local:  exit

SET SYSTEMD FOR KDC
Let’s start the Kerberos KDC and kadmin daemons

	% sudo systemctl start krb5kdc.service
	% sudo systemctl start kadmin.service
	% sudo systemctl enable krb5kdc.service
	% sudo systemctl enable kadmin.service

CREATE A PRINCIPAL
Now, let’s create a principal for our KDC server and stick it in it’s keytab:

	[root@kdc ~]# kadmin.local
	kadmin.local:  addprinc -randkey host/infra01.cloudmart.lan
	kadmin.local:  ktadd host/infra01.cloudmart.lan

SETUP KERBEROS CLIENT
There a couple of ways of creating the krb5.conf file. But this is a standand sysadmin way of getting it built by the server. 
1. On the Kerberos server execute:
	% sudo yum -y install krb5-workstation
	% sudo cp /etc/krb5.conf /tmp
2. Transfer your /etc/krb5.conf (which got created from above command) from the KDC server to the client. 
	% scp infra01.cloudmart.lan:/tmp/krb5.conf .
	% sudo mv krb5.conf /etc
	% ls -l /etc/krb5.conf
3. On the client server, install the Kerberos client package and add some host principals:

	% sudo yum install krb5-workstation
	% kadmin -p root/admin
	% kadmin:  addpinc --randkey host/admin01.cloudmart.com
	% kadmin:  ktadd host/kdc.example.com

SETTING UP SSH TO USE KERBEROS AUTHENTICATION
Make sure you can issue a kinit -k host/fqdn@REALM and get back a kerberos ticket without having to specify a password.

CONFIGURE SSH SERVER
1. Configure /etc/ssh/sshd_config file to include the following lines:

	KerberosAuthentication yes
	GSSAPIAuthentication yes
	GSSAPICleanupCredentials yes
	UsePAM no
2.  Now, restart the ssh daemon.
	sudo systemctl restart sshd

CONFIGURE SSH CLIENT
Configure /etc/ssh_config to include following lines:

	Host *.domain.com
  	GSSAPIAuthentication yes
  	GSSAPIDelegateCredentials yes
