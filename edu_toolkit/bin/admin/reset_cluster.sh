#!/bin/bash

# ------------------------------[ Documentation ]----------------------------------------
#
# This script performs the tasks to reset the cluster to one of four states in tha Admin lab exercise.
# The available states are:
# - Full Cluster reset: clean and nothing installed will be included in all four states
# - Cloudera Manager v7.3.1 installed
# - Cluster setup: cluster is configured with CDP 7.1.5; HDFS exercise completed
# - HA Cluster setup: cluster is configured with CDP 7.1.5 to the state after High Availabitity is configured
# - Final Setup: Cluster has been upgraded to CDH 7.1.6 and all services are installed
#
# It assumes that symbolic hostnames are already established
# and that there is IP addressability and passwordless SSH
# across the private interfaces of the nodes.
#
# The command prompts the user for a desired state are run from the cmhost server.
#
# (1) Check that the script is running on cmhost, if not exit.
#    The reset_cluster script depends on named nodes and that it is homed on cmhost
#
# (2) Prompts the user to choose one of the four states
#
# (3) Confirms user input in prior to proceed
#
# (4) Calls functions to cleanup
#
# (5) Calls appropriate function based off of user input
#

DIALOG_CANCEL=1
DIALOG_ESC=255
HEIGHT=15
WIDTH=60

resize -s 30 120

echo "Running "$0 "on "$(date)
echo
if [ $HOSTNAME != "cmhost" ]; then
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
    --infobox "$msg" 6 60; sleep 5
}

display_final_result() {
  dialog --title "$1" \
    --no-collapse \
    --msgbox "$msg" 8 70
}

cleanup(){
  title="INFO"
  msg=$(echo "Stopping all Hadoop processes, removing Hadoop software, removing files, and resetting other changes to your system.\nThis process will take a few minutes.")
  display_result $title
  $CATCHUP_DIR/"cleanup.sh"
}

doFullReset() {
  title="INFO"
  msg=$(echo "Installs CM Server and prepares MySQL - takes a few minutes.")
  display_result $title
  $CATCHUP_DIR/install-cmserver.sh
}

doConfigCluster() {
  title="INFO"
  msg=$(echo "Installing agents and configuring cluster - takes at least 10 minutes.")
  display_result $title 
  $CATCHUP_DIR/add-cluster-non-ha.sh
}

doConfigHA() {
  title="INFO"
  msg=$(echo "Configuring cluster for High Availability - takes at least 30 minutes.")
  display_result $title
  $CATCHUP_DIR/config-cluster-ha.sh
  #$CATCHUP_DIR/config-hdfs.sh
   #ssh training@cmhost -o StrictHostKeyChecking=no ~/training_materials/admin/scripts/catchup/config-cluster-ha.sh
  #ssh training@cmhost -o StrictHostKeyChecking=no ~/training_materials/admin/scripts/catchup/config-hdfs.sh
}

doFinalState() {
  title="INFO"
  msg=$(echo "Configuring cluster for Final State - takes at least 30 minutes.")
  display_result $title
  $CATCHUP_DIR/config-final-state.sh
  #$CATCHUP_DIR/config-hdfs.sh
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
       exit;;
     255)
       exit;;
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
      --menu "Please select the state to which you want the cluster configured. \n\nThis script will reset your cluster to that state." $HEIGHT $WIDTH 4 \
      "1" "Full cluster reset - CM installed" \
      "2" "Cluster setup" \
      "3" "High-availability setup" \
      "4" "Final setup CDP 7.1.3" \
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
        # Cloudera Manager installed - State 1 
        # Clean up install CM 
        getResetConfirmation $selection
        title="INFO"
        msg=$(echo "Advancing to State $selection at $(date +'%T')\nThis may take up to 15 minutes.")
        display_result $title
        #cleanup 
        #doFullReset
        ansible-playbook -i $CATCHUP_DIR/inventory --extra-vars="cluster_reset_state1=true" $CATCHUP_DIR/site.yml 2> /dev/null | dialog --title "Cluster Reset - Advancing to State $selection" --backtitle "Cluster Reset" --no-collapse --progressbox 20 100
        if [[ $(echo $?) == 0 ]]; then
          title="INFO"
          msg=$(echo "Cloudera Manager has been restored.\nCluster reset phase 1 completed at $(date +'%T').")
          display_final_result $title
        else
          title="ERROR"
          msg=$(echo "Please investigate and re-run the reset script again")
          display_result $title
          sleep 5
          exit 1
        fi
        ;;
      2 )
        # Cluster setup - State 2
        # 
	    getResetConfirmation $selection
        title="INFO"
        msg=$(echo "Advancing to State $selection at $(date +'%T')\nThis may take up to 30 minutes.")
        display_result $title
        ansible-playbook -i $CATCHUP_DIR/inventory --extra-vars="cluster_reset_state2=true" $CATCHUP_DIR/site.yml 2> /dev/null | dialog --title "Cluster Reset - Advancing to State $selection" --backtitle "Cluster Reset" --no-collapse --progressbox 20 100
        if [[ $(echo $?) == 0 ]]; then
          title="INFO"
          msg=$(echo "Cloudera Manager has been restored.\nCluster reset phase 2 completed at $(date +'%T').")
          display_final_result $title
        else
          title="ERROR"
          msg=$(echo "Please investigate and re-run the reset script again")
          display_result $title
          sleep 5
          exit 1
        fi
        ;;
      3 )
#       High-availability setup
        getResetConfirmation $selection
        title="INFO"
        msg=$(echo "Advancing to State $selection at $(date +'%T')\nThis may take up to 30 minutes.")
        display_result $title
        ansible-playbook -i $CATCHUP_DIR/inventory --extra-vars="cluster_reset_state3=true" $CATCHUP_DIR/site.yml 2> /dev/null | dialog --title "Cluster Reset - Advancing to State $selection" --backtitle "Cluster Reset" --no-collapse --progressbox 20 100
        if [[ $(echo $?) == 0 ]]; then 
          title="INFO"
          msg=$(echo "Cloudera Manager has been restored.\nCluster reset phase 3 completed at $(date +'%T').")
          display_final_result $title
        else
          title="ERROR"
          msg=$(echo "Please investigate and re-run the reset script again")
          display_result $title
          sleep 5
          exit 1
        fi
        ;;
      4 )
#       High-availability setup
        getResetConfirmation $selection
        title="INFO"
        msg=$(echo "Advancing to State $selection at $(date +'%T')\nThis may take up to 30 minutes.")
        display_result $title
        ansible-playbook -i $CATCHUP_DIR/inventory --extra-vars="cluster_reset_state4=true" $CATCHUP_DIR/site.yml 2> /dev/null | dialog --title "Cluster Reset - Advancing to State $selection" --backtitle "Cluster Reset" --no-collapse --progressbox 20 100
        if [[ $(echo $?) == 0 ]]; then
          title="INFO"
          msg=$(echo "Cloudera Manager has been restored.\n\nCluster reset phase 4 completed at $(date +'%T').")
#          dialog --title $title --msgbox $msg 6 60
          display_final_result $title
        else
          title="ERROR"
          msg=$(echo "Please investigate and re-run the reset script again")
          display_final_result $title
          sleep 5
          exit 1
        fi
        ;;
    esac
  done
}

#COMMENTED OUT

MYHOST="`hostname`: "
CATCHUP_DIR="/home/training/training_materials/admin/scripts/ansible/cloudera.cdp_dc-migration"
# Avoid "sudo: cannot get working directory" errors by
# changing to a directory owned by the training user

# The reset_cluster automatically takes you to a Full CM Installation state
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
