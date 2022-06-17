# validate kerberos
ssh nifi@hdf01
klist -kt /etc/security/keytabs/nifi.service.keytab
cat /etc/nifi/conf/nifi.properties | grep kerberos
tail /etc/nifi/conf/login-identity-providers.xml  

# 

# Logs
tail -f /var/log/nifi/nifi-app.log
tail -f /var/log/nifi/nifi-user.log

# Authorization
less /etc/nifi/conf/authorizors.xml
less /var/lib/nifi/conf/authorizations.xml
less /var/lib/nifi/conf/users.xml
