#!/usr/bin/env bash

# Copyright (c) 2017 Cloudera, Inc. All rights reserved.

# This script will generate credentials with a Red Hat IPA. The
# principal that CM is using to perform the following operations
# should be member of the admins group and/or have the ability to
# add services and hosts (call 'ipa service-add' and 'ipa host-add').
# It also requires the CM principal to have the ability to generate
# the keytab for the HTTP principal on the IPA server if that server
# is part of the cluster. Lastly, the principal must be able to
# authenticate to the kadmin server.
# The CM machine has to have the ipa admin tools installed in order
# to run this script.

set -e
set -x

CMF_REALM=${CMF_PRINCIPAL##*\@}

# Explicitly add RHEL5/6, SLES11/12 locations to path
export PATH=$PATH:/usr/kerberos/bin:/usr/kerberos/sbin:/usr/lib/mit/sbin:/usr/sbin:/usr/lib/mit/bin:/usr/bin

# first, get ticket for CM principal
kinit -k -t $CMF_KEYTAB_FILE $CMF_PRINCIPAL

KEYTAB_OUT=$1
PRINCIPAL=$2
MAX_RENEW_LIFE=$3

if [ -z "$KRB5_CONFIG" ]; then
  echo "Using system default krb5.conf path."
else
  echo "Using custom config path '$KRB5_CONFIG', contents below:"
  cat $KRB5_CONFIG
fi

# PRINCIPAL is in the full service/fqdn@REALM format. Parse to determine
# principal name and host.
PRINC=${PRINCIPAL%%/*}
HOST=`echo $PRINCIPAL | cut -d "/" -f 2 | cut -d "@" -f 1`

# Create the host if needed.
set +e
ipa host-show $HOST
ERR=$?
set -e
if [[ $ERR -eq 0 ]]; then
  echo "Host $HOST exists"
else
  echo "Adding new host: $HOST"
#  ipa host-add $HOST --force --no-reverse
##changed to accomodate PrivateCloud
  if [[ $HOST =~ \. ]]; then
    ipa host-add $HOST --force --no-reverse
  else
    ipa host-add $HOST.apps.ecs-1.example.com --force --no-reverse
  fi
#end change
fi

set +e
ipa service-show $PRINCIPAL
ERR=$?
set -e
if [[ $ERR -eq 0 ]]; then
  echo "Principal $PRINCIPAL exists"
  PRINC_EXISTS=yes
else
  PRINC_EXISTS=no
  echo "Adding new principal: $PRINCIPAL"
  ipa service-add $PRINCIPAL --force
fi

# Set the maxrenewlife for the principal, if given. There is no interface
# offered by the IPA to set it, so we use KADMIN as suggested in a few IPA
# related forums.
KADMIN="kadmin -k -t $CMF_KEYTAB_FILE -p $CMF_PRINCIPAL -r $CMF_REALM"

if [ $MAX_RENEW_LIFE -gt 0 ]; then
  $KADMIN -q "modprinc -maxrenewlife \"$MAX_RENEW_LIFE sec\" $PRINCIPAL"
fi

KEYTAB_PATH=/tmp/${PRINC}_${HOST}.keytab

# ipa-getkeytab generates new password for the principal, by default. There
# is one place where doing this will break everything, and this is the
# credentials for the httpd daemon used by the IPA itself. If we re-generate
# the keytab for this  principal access to the IPA through the IPA client,
# e.g., ipa service-find, will start failing. We will just retrieve the
# credentials for this principal. Note that this requires the admin to allow
# the CM principal to retrieve the keytab for this principal by running something
# like:
# ipa service-allow-retrieve-keytab HTTP/<host fqdn>@REALM  --users=<cm principal>
# Also note that the above is only supported from IPA version 3.3 and up. This
# script will not work on earlier versions.
# 'ipa env server' returns something like:
# >  ipa env server
#  host: foobar.bar.foo.com
IPA_HOST=$(ipa env server | tr -d '[:space:]' | cut -f2 -d:)
if [[ "$PRINC_EXISTS" = "yes" && "${PRINCIPAL:0:5}" = "HTTP/" && "$IPA_HOST" = "$HOST" ]] ; then
  echo "Attempting to retrieve keytab for IPA HTTP principal. To grant the right to do so, run:\n " \
    "\tipa service-allow-retrieve-keytab HTTP/${IPA_HOST}@REALM  --users=${CMF_PRINCIPAL}"
  ipa-getkeytab -r --principal=$PRINCIPAL --keytab=$KEYTAB_PATH
else
  ipa-getkeytab --principal=$PRINCIPAL --keytab=$KEYTAB_PATH
fi

if [ ! -e $KEYTAB_PATH ] ; then
  echo "[ERROR]: keytab not downloaded for principal: $PRINCIPAL"
  kdestroy
  exit 1
else
  CMD="cp $KEYTAB_PATH $KEYTAB_OUT"
  eval $CMD
  rm -f $KEYTAB_PATH
fi

kdestroy
exit 0
