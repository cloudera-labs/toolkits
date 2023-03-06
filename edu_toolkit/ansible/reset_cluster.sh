#!/bin/bash

# ------------------------------[ Documentation ]----------------------------------------
#
# This script performs Ansible job to reset the cluster to one of the available states in the CDP Security lab exercises.
# The available states are:
# - Stage 1: Full CDP Cluster reset: Teardown the Implemented Cluster and rebuild it to the Initial setup. After reset, proceed with Module 8 : Encrypting Network Traffic
# - Stage 2: CDP with TLS and KRB: Teardown the Implemented Cluster and rebuild it with Auto-TLS and Kerberos enabled. After reset, proceed with Module 11 : Deploying CDP Runtime
# - Stage 3: CDP with SDX :  Teardown the Implemented Cluster and rebuild it with SDX (Ranger, Ranger RMS , Atlas) enabled. Note: Auto-TLS and Kerberos will be enabled as a prerequisite for SDX. After reset, proceed with Module 14 : Install Key Trustee Server
# - Stage 4: CDP with HDFS Data At Rest: Teardown the Implemented Cluster and rebuild it with HDFS Data At Rest Encryption enabled. Note: Auto-TLS, Kerberos and SDX will be enabled as a prerequisite for HDFS Data At Rest Encryption. After reset, proceed with Module 16 : Install Knox Gateway
# - Stage 5: CDP with Knox GatewayTeardown the Implemented Cluster and rebuild it with Knox and SSO Configured. Previous stages will be included in this stage. After reset, proceed with Module 17 : Creating Ranger Policies
#
# Note: It may take upto 45 mins for the script to run. 
#

DIALOG_CANCEL=1
DIALOG_ESC=255
HEIGHT=15
WIDTH=60

resize -s 30 120

echo "Running "$0 "on "$(date)
echo
if [ $HOSTNAME != "cmhost" || $HOSTNAME != "cmhost.example.com" ]; then
	echo "This script should only be run on cmhost. It appears you are running this on " $HOSTNAME
	echo "Exiting..."
	sleep 5
	exit 0
else
  exercise=2
  initialState=1
fi
echo "Verified hostname is "$HOSTNAME". Continuing..."


display_result() {
  dialog --title "$1" \
    --no-collapse \
    --msgbox "$msg" 6 60; sleep 5
}

display_final_result() {
  dialog --title "$1" \
    --no-collapse \
    --msgbox "$msg" 8 70
}

getResetConfirmation() {
   dialog --clear --title "Cluster Reset Confirmation" \
   --backtitle "Cluster Reset" \
   --no-collapse \
   --yesno "You are about to reset your cluster to State "$1". Do you want to proceed?" 6 80
   case $? in
     0)
       ;;
     1)
       getStartState;;
     255)
       getStartState;;
    esac
}

getStartState() {
  while true; do
    exec 3>&1
    selection=$(dialog \
      --backtitle "Catch Up Scripts" \
      --title "Cluster restore" \
      --clear \
      --cancel-label "Exit" \
      --menu "Please select the state to which you want the cluster configured. \n\nThis script will reset your cluster to that state." $HEIGHT $WIDTH 6 \
      "1" "CDP Initial Setup" \
      "2" "CDP with TLS and KRB" \
      "3" "CDP with SDX" \
      "4" "CDP with HDFS Data At Rest" \
      "5" "CDP with Knox Gateway" \
      2>&1 1>&3)
    exit_status=$?
    exec 3>&-
    case $exit_status in
      $DIALOG_CANCEL)
        clear
        echo "Program terminated."
        exit
        ;;
      $DIALOG_ESC)
        clear
        echo "Program aborted." >&2
        exit 1
        ;;
    esac
    case $selection in
      0 )
        clear
        echo "Program terminated."
        ;;
      1 )
        # State 1 
        getResetConfirmation $selection
        title="INFO"
        msg=$(echo "Advancing to State $selection at $(date +'%T')\nThis may take up to 45 minutes.")
        display_result $title
        ansible-playbook -i $CATCHUP_DIR/inventory --extra-vars="tls=no krb=no sdx=no encryption=no knox=no" $CATCHUP_DIR/site.yml -f 13 
# 2> /dev/null | dialog --title "Cluster Reset - Advancing to State $selection" --backtitle "Cluster Reset" --no-collapse --progressbox 20 100
        if [[ $(echo $?) == 0 ]]; then
          title="INFO"
          msg=$(echo "CDP Cluster has been restored.\nCluster reset phase 1 completed at $(date +'%T').")
          display_final_result $title
        else
          title="ERROR"
          msg=$(echo "Please investigate and check Ansible logs, you may need to re-run the reset script again")
          display_result $title
          sleep 5
          exit 1
        fi
        ;;
      2 )
        # State 2
	    getResetConfirmation $selection
        title="INFO"
        msg=$(echo "Advancing to State $selection at $(date +'%T')\nThis may take up to 60 minutes.")
        display_result $title
        ansible-playbook -i $CATCHUP_DIR/inventory --extra-vars="security=true tls=yes krb=yes sdx=no encryption=no knox=no" $CATCHUP_DIR/site.yml -f 13 #2> /dev/null | dialog --title "Cluster Reset - Advancing to State $selection" --backtitle "Cluster Reset" --no-collapse --progressbox 20 100
        if [[ $(echo $?) == 0 ]]; then
          title="INFO"
          msg=$(echo "CDP Cluster has been restored.\nCluster reset phase 2 completed at $(date +'%T').")
          display_final_result $title
        else
          title="ERROR"
          msg=$(echo "Please investigate and check Ansible logs, you may need to re-run the reset script again")          
          display_result $title
          sleep 5
          exit 1
        fi
        ;;
      3 )
        # State 3
        getResetConfirmation $selection
        title="INFO"
        msg=$(echo "Advancing to State $selection at $(date +'%T')\nThis may take up to 60 minutes.")
        display_result $title
        ansible-playbook -i $CATCHUP_DIR/inventory --extra-vars="security=true tls=yes krb=yes sdx=yes encryption=no knox=no" $CATCHUP_DIR/site.yml -f 13 #2> /dev/null | dialog --title "Cluster Reset - Advancing to State $selection" --backtitle "Cluster Reset" --no-collapse --progressbox 20 100
        if [[ $(echo $?) == 0 ]]; then 
          title="INFO"
          msg=$(echo "CDP Cluster has been restored.\nCluster reset phase 3 completed at $(date +'%T').")
          display_final_result $title
        else
          title="ERROR"
          msg=$(echo "Please investigate and check Ansible logs, you may need to re-run the reset script again")
          display_result $title
          sleep 5
          exit 1
        fi
        ;;
      4 )
        # State 4
        getResetConfirmation $selection
        title="INFO"
        msg=$(echo "Advancing to State $selection at $(date +'%T')\nThis may take up to 60 minutes.")
        display_result $title
        ansible-playbook -i $CATCHUP_DIR/inventory --extra-vars="security=true tls=yes krb=yes sdx=yes encryption=yes knox=no" $CATCHUP_DIR/site.yml #2> /dev/null | dialog --title "Cluster Reset - Advancing to State $selection" --backtitle "Cluster Reset" --no-collapse --progressbox 20 100
        if [[ $(echo $?) == 0 ]]; then
          title="INFO"
          msg=$(echo "CDP Cluster has been restored.\n\nCluster reset phase 4 completed at $(date +'%T').")
#          dialog --title $title --msgbox $msg 6 60
          display_final_result $title
        else
          title="ERROR"
          msg=$(echo "Please investigate and check Ansible logs, you may need to re-run the reset script again")
          display_final_result $title
          sleep 5
          exit 1
        fi
        ;;
      5 )
        # State 5
        getResetConfirmation $selection
        title="INFO"
        msg=$(echo "Advancing to State $selection at $(date +'%T')\nThis may take up to 60 minutes.")
        display_result $title
        ansible-playbook -i $CATCHUP_DIR/inventory --extra-vars="security=true tls=yes krb=yes sdx=yes encryption=yes knox=yes" $CATCHUP_DIR/site.yml -f 13 #2> /dev/null | dialog --title "Cluster Reset - Advancing to State $selection" --backtitle "Cluster Reset" --no-collapse --progressbox 20 100
        if [[ $(echo $?) == 0 ]]; then 
          title="INFO"
          msg=$(echo "CDP Cluster has been restored.\nCluster reset phase 5 completed at $(date +'%T').")
          display_final_result $title
        else
          title="ERROR"
          msg=$(echo "Please investigate and check Ansible logs, you may need to re-run the reset script again")
          display_result $title
          sleep 5
          exit 1
        fi
        ;;
    esac
  done
}

MYHOST="`hostname`: "
CATCHUP_DIR=/home/training/training_materials/security/ansible

cd ~

# Prompt User for initial state.
getStartState
echo 
echo $MYHOST $0 "done." 
echo ""
echo "################################################################"
echo "Cluster reset successfully completed at $(date +'%T')."
echo "You can now continue with the exercises."
echo "################################################################"