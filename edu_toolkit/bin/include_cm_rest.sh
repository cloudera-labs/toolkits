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
# Author: KNY 
# Date: 1MAR18
# Purpose: This script contains a list of CM REST API functions. It should
# be called into another script and the functions populated as needed.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLES
CM_AUTH=${CM_USER:-admin}:${CM_PASS:-admin}
CM_URI=${CM_SERVER:-localhost}:${CM_PORT:-7180}
CM_API=${CM_API:-v14}
CM_NAME=Cluster1

CM_GET="-su $CM_AUTH http://$CM_URI/api/$CM_API"
CM_GET_SVC="$CM_GET/clusters/$CM_NAME/services"
CM_POST="$CM_GET/clusters/$CM_NAME"

# '$tombstone' settings
BAD_CONF="Incorrect configuration"
STALE="Stale configuration"
MISSING_FILE="File(s) not found"
MISSING_DIR="Directory not found"
MISSING_RES="Resource not found"
BAD_PERMS="Incorrect permissions"
NOT_INSTALLED="Service not installed"

# FUNCTIONS
function cm_full_restore(){
    [ -z "$1" ] && { echo "Must provide a filename to upload."; return 1; }
    curl --upload-file $1 -X PUT -H "Content-Type:application/json" \
    $CM_GET/cm/deployment?deleteCurrentDeployment=true
}

function cm_list_functions(){
    # Replace this function call with the listing of all the functions
    out=$(awk -F'{| ' '/^ *function/{a=$2; getline; printf "# %-30s%s\\n", a, $0}' $(which cm_functions))
    sed -i 's/^cm_list_functions$/'"$out"'/' $0
    return
}

function cm_dump_all() {
    # Output the entire dump
    curl $CM_GET/cm/deployment
}

function cm_restore_all(){
    # Restore cluster state | args: cm_snapshot_state
    curl --upload-file $1 $CM_GET/cm/deployment?deleteCurrentDeployment=true
}

function cm_check_service_staleness(){
    # Check the cluster services for staleness | arg: svc_name
    out=$(curl $CM_GET_SVC/$1)
    val=$(awk -F'"' '/\<configStalenessStatus\>/{print $4}' <<< "$out" 2>/dev/null)
    if [ -z "$val" ]
    then
        awk -F'"' '/"message" :/{print $4}' <<< "$out" >&2
    else
        echo $val
    fi
}

function cm_check_CMS_staleness(){
    # Check the CM server (management service) for staleness
    out=$(curl $CM_GET/cm/service)
    val=$(awk -F'"' '/\<configStalenessStatus\>/{print $4}' <<< "$out")
    if [ -z "$val" ]
    then
        awk -F'"' '/"message" :/{print $4}' <<< "$out" >&2
    else
        echo $val
    fi
}

function cm_check_settings(){
    # Retrieve a setting from CM | arg: ([param]=val) or ([param1]=val1 [param2]=val2 ...)
    retval=0
    egrep -q '^\((\[[^ ]+\]=[^ ]+ ?)+\)$' <<< "$1" || {
        echo "Improperly constructed argument: must be '([key]=value)' or '([key1]=value1 [key2]=value2 ...)'"
        return 1
    }
    declare -A test_array=$1
    [ -z "${test_array[*]}" ] && { echo "Unable to construct test array"; return 1; }

    for var in ${!test_array[*]}
    do
        val=${test_array[$var]}

        # Extract and reformat the name/value pairs for matching entries
        match=$(cm_dump_all|awk -v n="$var" -F '"' '{if(n==$4){getline;print n"="$4}}')

        # Set name/value pairs as shell variables
        while read i; do eval $i; done <<< "$match"

        echo "Current value: '$var' '${!var}'" >&2
        echo "Expected value: '$var' '$val'" >&2

        if [ "${!var}" = "${test_array[$var]}" ]
        then
            echo "Success: Configuration setting correct" >&2
        else
            echo "Failure: $var is set to '${!var}' instead of ${test_array[$var]}" >&2
            retval=1
        fi
    done
    return $retval
}

function cm_get_config(){
    # Returns value for $setting in $service | args: service setting_name | ret: value
    [ -z "$2" ] && { echo "$0 <service> <setting_name>"; return 1; }
    curl $CM_GET_SVC/$1/roleConfigGroups|\
        awk -F'"' '/'"$2"'/{getline;print $4}'
}

function cm_set_config(){
    # Set configuration items | args: svc_name roleConfigGroup '{ "name" : "", "value" : "" }'
    curl -X PUT -H "Content-Type:application/json" \
    -d '{ "items": [ '"$3"' ] }' \
    $CM_GET_SVC/$1/roleConfigGroups/$2/config > /dev/null 2>&1
}
 
function cm_mgmt_get(){
    # Get the value of a CM setting | args: (mgmt-)ROLE(-BASE) setting_name

    # mgmt-TELEMETRYPUBLISHER-BASE
    # mgmt-SERVICEMONITOR-BASE
    # mgmt-REPORTSMANAGER-BASE
    # mgmt-NAVIGATORMETASERVER-BASE
    # mgmt-NAVIGATOR-BASE
    # mgmt-HOSTMONITOR-BASE
    # mgmt-EVENTSERVER-BASE
    # mgmt-ALERTPUBLISHER-BASE
    # mgmt-ACTIVITYMONITOR-BASE

    curl $CM_GET/cm/service/roleConfigGroups/$1/config?view=full|\
        r=$2 perl -wlne'$n = $ENV{r} if /"name" : "$ENV{r}"/; print $1
            and exit if $n and /"(?:value|default)" : "([^"]+)"/'
}

function cm_mgmt_set(){
    # Set values within CM management roles | args: (mgmt-)ROLE(-BASE) name value

    [ -z "$3" ] && { echo "args: ROLE name value" >&2; return 1; }
    role=$(sed 's/^mgmt-//; s/-BASE//; s/.*/mgmt-&-BASE/' <<< "$1")

    out=$(curl -X PUT -H "Content-Type:application/json" \
      -d '{ "items": [ { "name": "'$2'", "value": "'$3'" } ] }' \
        $CM_GET/cm/service/roleConfigGroups/$role/config|\
        awk -v n="$2" -F '"' '{if(n==$4){getline;print $4}}')
    if [ "$out" -eq "$3" ]
    then
        return 0
    else
        return 1
    fi
}

function cm_service_start(){
    # Start the specified service | args: svcname
    curl -X POST -H "Content-Type:application/json" \
        $CM_GET_SVC/$1/commands/start > /dev/null 2>&1
    echo -n "Restarting $1..." >&2
    count=0
    until curl $CM_GET_SVC/$1|grep -q '"entityStatus" : "GOOD_HEALTH"'
    do
        ((count++))
        # Fail out of staging completely
        [ "$count" -eq 120 ] && exit 100
        sleep 5
    done
    echo -e "\r$1 service started." >&2
}

function cm_service_restart(){
    # Restart the specified service | args: svcname
    curl -X POST -H "Content-Type:application/json" \
        $CM_GET_SVC/$1/commands/restart > /dev/null 2>&1
    echo -n "Restarting $1..." >&2
    count=0
    until curl $CM_GET_SVC/$1|grep -q '"entityStatus" : "GOOD_HEALTH"'
    do
        ((count++))
        # Fail out of starting service completely
        [ "$count" -eq 120 ] && exit 100
        sleep 5
    done
    echo -e "\r$1 service restarted." >&2
}

function cm_service_stop(){
    # Stop the specified service | args: svcname
    curl -X POST -H "Content-Type:application/json" \
        $CM_GET_SVC/$1/commands/stop > /dev/null 2>&1
    echo -n "Stopping $1..." >&2
    count=0
    until curl $CM_GET_SVC/$1|grep -q '"entityStatus" : "STOPPED"'
    do
        ((count++))
        # Fail out of stopping service completely
        [ "$count" -eq 120 ] && exit 100
        sleep 5
    done
    echo -e "\r$1 service stopped." >&2
}

function cm_service_deploy(){
    # Redeploy the specified service | args: svcname
    curl -X POST -H "Content-Type:application/json" \
        $CM_GET_SVC/$1/commands/deployClientConfig > /dev/null 2>&1
    echo -n "Restarting $1..." >&2
    count=0
    until curl $CM_GET_SVC/$1|grep -q '"entityStatus" : "GOOD_HEALTH"'
    do
        ((count++))
        # Fail out of staging completely
        [ "$count" -eq 120 ] && exit 100
        sleep 5
    done
    echo -e "\r$1 service restarted." >&2
}

function cm_cms_restart(){
    # Restart the Cloudera Management service
    curl -X POST -H "Content-Type:application/json" \
        $CM_GET/cm/service/commands/restart > /dev/null 2>&1
    echo -n "Restarting CMS..." >&2
    count=0
    until curl $CM_GET/cm/service|grep -q '"entityStatus" : "GOOD_HEALTH"'
    do
        ((count++))
         #CMS is not started after 1,5 minutes; restart CM.
         if [[ "$count" -eq 12 ]] || [[ "$count" -eq 60 ]]; then
            echo -n "Restarting CMS at counter: $count" 
            curl -X POST -H "Content-Type:application/json" \
              $CM_GET/cm/service/commands/restart > /dev/null 2>&1
         fi

        # Fail out of staging completely
        [ "$count" -eq 120 ] && exit 100
        sleep 5
    done
    echo -e "\rCMS service restarted." >&2
}

function cm_cms_start(){
    # Start Cloudera Management Service
    curl -X POST -H "Content-Type:application/json" \
        $CM_GET/cm/service/commands/start > /dev/null 2>&1
    echo -n "Starting CMS..." >&2
    count=0
    until curl $CM_GET/cm/service|grep -q '"entityStatus" : "GOOD_HEALTH"'
    do
        ((count++))
         #CMS is not started after 1,3 minutes; restart CM.
         if [[ "$count" -eq 12 ]] || [[ "$count" -eq 60 ]]; then
            echo -n "Restarting CMS at counter: $count" 
            curl -X POST -H "Content-Type:application/json" \
              $CM_GET/cm/service/commands/start > /dev/null 2>&1
         fi
        # Fail out of staging completely
        [ "$count" -eq 120 ] && exit 100
        sleep 5
    done
    echo -e "\rCMS service started." >&2
}

function cm_cluster_redeploy(){
    # Redeploy the Cluster
    curl -X POST -H "Content-Type:application/json" \
        $CM_POST/commands/restart?redeployClientConfiguration=true > /dev/null 2>&1 
    echo -n "Redeploying cluster..." >&2
    count=0
    until curl $CM_GET/clusters/$CM_NAME|grep -q '"entityStatus" : "GOOD_HEALTH"'
    do
        ((count++))
        # Fail out of staging completely
        [ "$count" -eq 120 ] && exit 100
        sleep 5
    done
    echo -e "\rCM cluster restarted." >&2
}

function cm_cluster_staleness_restart(){
    # Restart only stale services on cluster
    curl -X POST -H "Content-Type:application/json" \
        $CM_POST/commands/restart?restartOnlyStaleServices=true > /dev/null 2>&1
    echo -n "Restarting cluster..." >&2
    count=0
    until curl -X GET $CM_GET/clusters/$CM_NAME|grep -q '"entityStatus" : "GOOD_HEALTH"'
    do
        ((count++))
        # Fail out of staging completely
        [ "$count" -eq 120 ] && exit 100
        sleep 5
    done
    echo -e "\rCM cluster restarted." >&2
}


