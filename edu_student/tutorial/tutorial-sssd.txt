SSSD and LDAP

All LDAP identity stores include schema that supports UNIX attributes. This includes the following objectclasses.

     ☑ posixAccount – Used for UNIX user attributes
     ☑ posixGroup – Userd for UNIX group attributes

Typically when describing a user or group, the object classes inetOrgPerson and groupOfUniqueNames are used respectively. However, neither posixAccount or posixGroup are part of the inetOrgPerson and groupOfUniqueName structural classes. Therefore, you can either add posixAccount to a user’s object in order to get uidNumber, gidNumber, loginShell, and homeDirectory, and add posixGroup objectclass to a group to get the gidNumber attribute. Alternatively, you can create a custom object class and incorporate both needed classes.

For example, you could create acmePerson and include inetOrgPerson and posixAccount classes to get all the needed attributes to describe a user that includes UNIX attributes. Similar for a custom group class, use both groupOfUniqueNames and posixGroup. More on mapping the appropriate attributes later in the implementation sections.

UNIX UID and GID Numbers

In UNIX when a user is created they typically will automatically be assigned a user ID number and a group ID number. That said, every Linux user must have a UID and a primary GID to successfully authenticate.

id <user>
Example: id adina
uid=20003(adina) gid=95001(Linux) groups=95001(Linux)

When using SSSD, the uidNumber and gidNumber come from the LDAP identity store. Once a user logs into a system or service with SSSD, it caches the user name with the associated UID/GID numbers. The UID number is used as the identifying key for the user. If a user with the same username but a different UID attempts to log into the system, then SSSD treats it as two different users with a name collision. This has nothing to do with SSSD, this is how UNIX works.

It is important to understand that SSSD does not recognize a UID number change, it only sees it as a different and new user, not an existing user with a different UID number. If an existing user UID number changes they will be denied login. This also has the same impact with accounts used by client applications which are stored in an identity store. If a user does have a UID change someone as root will need to run the following command to remove the cache. Now the user can try to login again.

[root@host]  sss_cache –u adina

TIP:  It should be noted that SSSD provides a way to act as a client of Active Directory without requiring administrators to extend user attributes to support POSIX attributes used for user and group identifiers.  When ID-mapping is enabled, SSSD will use an algorithm by using the objectSID to generate the needed mapping ids.
UNIX Home Directory and Login Shell

In UNIX a home directory, also called a login directory, is the directory on the operating system that is the user’s personal repository. It is also the directory the user first lands in after logging in. When using SSSD, the home directory is defined in the sssd.conf using the parameter ldap_user_home_directory which map to the appropriate LDAP attribute. Then for the UNIX shell, this is a command-line interpreter, that provides the user their command line user interface. When using SSSD, the ldap_user_shell parameter is used in sssd.conf to map to the corresponding LDAP identity source attribute and value. Depending on the LDAP identity store used, the attributes for home directory and login shell will be mapped in the /etc/sssd/sssd.conf file. More details on how this will all be configured later in the implementation sections.
 
TLS/LDAPS Requirements for SSSD

Because SSSD sends sensitive information across the wire between the Linux server and LDAP identity store when logging in such as a password, encrypting the LDAP communication is required by SSSD using either SSL or TLS. However, TLS is highly recommended and will only be used in articles from this point forward. SSL has many security vulnerabilities such as Heartbleed, POODLE, DROWN attack, etc. and from a security best practice it is highly recommended to avoid SSL and use TLS instead.

Since there are many ways to generate and configure SSL/TLS certificates for LDAPS, this effort is out-of-scope in this article. Just as a note, the encrypted traffic going from SSSD to LDAP does not need be all the way to the LDAP Identity Store, it can be terminated at a load balancer if that is the desired architecture. The only requirement is LDAP communication going from SSSD needs to be encrypted otherwise authentication using SSSD will not work.
