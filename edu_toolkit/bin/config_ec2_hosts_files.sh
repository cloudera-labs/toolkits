#!/bin/bash
# -------------------------[ Documentation ]------------------------------
#
# (1) Verify whether /etc/hosts file has a previous configurations, if not ask user
#    to add nodes IPs.
#
#
# (2) Perform a clean up job on /etc/hosts to prevent duplicate entries.
#
# (3) Fix cmhost hostname IP address in case of misconfiguration.
#
# (4) Backup and update /etc/hosts file with the nodes IPs in prior to propagate it to the
#      cluster nodes. Entered private IPs will be validated acconrdingly.
#
# (5) Confirms connectivity to cluster nodes (masters/workers).
#
# (6) Copy /etc/hosts from cmhost to other cluster nodes (masters/workers).
#
# (7) Manage to set cluster nodes hostname as required and perform Os reboot.

classenv=ec2

LOG_DIR=/home/training/bin/logs
mkdir -p $LOG_DIR
#CLEANUP_LOG="`date +%F`-CM7.1.3-CleanUp.log"
LOG_FILE="`date +%Y-%m-%d_%H-%M-%S`-config-hosts.log"
exec 2> $LOG_DIR/$LOG_FILE

echo "Running script on " $(date)
if [ $HOSTNAME != "cmhost" ]; then
    echo "This script should only be run on cmhost. It appears you are running this on " $HOSTNAME
    echo "Exiting..."
    sleep 5
    exit 0
fi

verify(){
  checkm=$(cat /etc/hosts | egrep "master|worker")
  if [[ "$checkm" != "" ]]; then
    validResponse=0
    while [ $validResponse -eq 0 ]
    do
      dialog --title "Verify /etc/hosts contents" \
      --backtitle "Cluster Network Configuration" \
      --no-collapse \
      --yesno "CAUTION: It looks like you already have entries for master and/or worker nodes in your /etc/hosts file.

This typically indicates that this script has already been run once.

The current contents of your /etc/hosts file appears between the dashed lines below:
------------------------------------------------------------
`cat /etc/hosts`
------------------------------------------------------------
Are you sure that you want to run this script again?" 30 80
      validResponse=$?
      case $validResponse in
      0) validResponse="1";;
      1)  dialog --title “Hosts/IPs” \
           --backtitle "Cluster Network Configuration" \
           --no-collapse \
           --msgbox "Ok, Exiting the script" 6 30
          exit 1;;
      255) dialog --title “Hosts/IPs” \
           --backtitle "Cluster Network Configuration" \
           --no-collapse \
           --msgbox "Ok, Exiting the script" 6 30
          exit 1;;
      esac
    done
  fi
}

removeCruft() {
  # Backup /etc/hosts
  sudo cp -p /etc/hosts /etc/hosts-BKP-`date +%Y-%m-%d_%H-%M-%S`
  if [ -f /home/training/.ssh/known_hosts ]; then
    rm /home/training/.ssh/known_hosts
  fi
  sudo sed -i '/master-1/d' /etc/hosts
  sudo sed -i '/master-2/d' /etc/hosts
  sudo sed -i '/worker-1/d' /etc/hosts
  sudo sed -i '/worker-2/d' /etc/hosts
  sudo sed -i '/worker-3/d' /etc/hosts
} &> /dev/null

fix_cmhost_hosts(){
  #fix private ip entry in hosts
  cmPrivIP=$(ip addr | grep eth0 | grep inet | awk '{print $2}' | cut -d '/' -f1)
  sudo sed -i '/cmhost/d' /etc/hosts
  echo $cmPrivIP" cmhost.example.com cmhost" | sudo tee -a /etc/hosts

  if [ ! -f /home/training/.ssh/id_rsa ]; then
    cp /home/training/.ssh/admincourse.pem /home/training/.ssh/id_rsa
    sudo cp /root/.ssh/admincourse.pem /root/.ssh/id_rsa
  fi
} &> /dev/null

updateHostsFile() {
    #################
      validateIp() {
      invalidIP=$1
      if [[ $invalidIP == "1" ]] ; then
        dialog --title “Hosts/IPs” \
        --backtitle "Cluster Network Configuration" \
        --no-collapse \
        --yesno "You have entered a private IP address that does not start with 10, 172, or 192.168.

Would you like to proceed with this? If not please press No and re-run the script once again" 9 80
        case $? in
          0)
            ;;
          1)
            exit;;
          255)
            exit;;
        esac
       fi
       }


    invalidIP=0
    echo
#    echo "What is the EC2 private IP address of your master-1 machine?"
#    echo "Private IP addresses usually start with 10, 172, or 192.168."
#    read ipm1
    exec 3>&1
    ipm1=$(dialog --clear --ok-label "Submit" \
          --backtitle "Cluster Network Configuration" \
          --title "Configure Hosts/IPs" \
          --form "What is the EC2 private IP address of your master-1 machine?s" \
          15 50 0 \
          "ip address : "    1 1  "$master1"      1 11 15 0 \
          2>&1 1>&3)
    if [[ $ipm1 != 10.* && $ipm1 != 172.* && $ipm1 != 192.168.* ]]; then
      invalidIP=1
      validateIp $invalidIP
    fi

    invalidIP=0
    #echo
    #echo "What is the EC2 private IP address of your master-2 machine?"
    #read ipm2
    exec 3>&1
    ipm2=$(dialog --clear --ok-label "Submit" \
          --backtitle "Cluster Network Configuration" \
          --title "Configure Hosts/IPs" \
          --form "What is the EC2 private IP address of your master-2 machine?" \
          15 50 0 \
          "ip address : "    1 1  "$master2"      1 11 15 0 \
          2>&1 1>&3)
    if [[ $ipm2 != 10.* && $ipm2 != 172.* && $ipm2 != 192.168.* ]]; then
      invalidIP=1
      validateIp $invalidIP
    fi

    invalidIP=0
    #echo
    #echo "What is the EC2 private IP address of your worker-1 machine?"
    #read ipw1
    exec 3>&1
    ipw1=$(dialog --clear --ok-label "Submit" \
          --backtitle "Cluster Network Configuration" \
          --title "Configure Hosts/IPs" \
          --form "What is the EC2 private IP address of your worker-1 machine?" \
          15 50 0 \
          "ip address : "    1 1  "$worker1"      1 11 15 0 \
          2>&1 1>&3)
    if [[ $ipw1 != 10.* && $ipw1 != 172.* && $ipw1 != 192.168.* ]]; then
      invalidIP=1
      validateIp $invalidIP
    fi

    invalidIP=0
    #echo
    #echo "What is the EC2 private IP address of your worker-2 machine?"
    #read ipw2
    exec 3>&1
    ipw2=$(dialog --clear --ok-label "Submit" \
          --backtitle "Cluster Network Configuration" \
          --title "Configure Hosts/IPs" \
          --form "What is the EC2 private IP address of your worker-2 machine?" \
          15 50 0 \
          "ip address : "    1 1  "$worker2"      1 11 15 0 \
          2>&1 1>&3)
    if [[ $ipw2 != 10.* && $ipw2 != 172.* && $ipw2 != 192.168.* ]]; then
      invalidIP=1
      validateIp $invalidIP
    fi

    invalidIP=0
    #echo
    #echo "What is the EC2 private IP address of your worker-3 machine?"
    #read ipw3
    exec 3>&1
    ipw3=$(dialog --clear --ok-label "Submit" \
          --backtitle "Cluster Network Configuration" \
          --title "Configure Hosts/IPs" \
          --form "What is the EC2 private IP address of your worker-3 machine?" \
          15 50 0 \
          "ip address : "    1 1  "$worker31"      1 11 15 0 \
          2>&1 1>&3)
    if [[ $ipw3 != 10.* && $ipw3 != 172.* && $ipw3 != 192.168.* ]]; then
      invalidIP=1
      validateIp $invalidIP
    fi
##################
    dialog --title “Hosts/IPs” \
    --backtitle "Cluster Network Configuration" \
    --yesno "Please verify that these are the correct IP addresses:
    "master-1:" $ipm1
    "master-2:" $ipm2
    "worker-1:" $ipw1
    "worker-2:" $ipw2
    "worker-3:" $ipw3" 10 60
# Get exit status
# 0 means user hit [yes] button.
# 1 means user hit [no] button.
# 255 means user hit [Esc] key.
     response=$?
     case $response in
     0)  ;;
     1)  dialog --title “Hosts/IPs” \
        --backtitle "Cluster Network Configuration" \
        --no-collapse \
        --msgbox "Please restart this script and provide the correct and valid IP addresses." 7 80
         exit 111 ;;
     255) dialog --title “Hosts/IPs” \
        --backtitle "Cluster Network Configuration" \
        --no-collapse \
        --msgbox "Please restart this script and provide the correct and valid IP addresses." 7 80
         exit 111 ;;
     esac

    sudo sh -c "echo $ipm1 master-1.example.com master-1 >> /etc/hosts"
    sudo sh -c "echo $ipm2 master-2.example.com master-2 >> /etc/hosts"
    sudo sh -c "echo $ipw1 worker-1.example.com worker-1 >> /etc/hosts"
    sudo sh -c "echo $ipw2 worker-2.example.com worker-2 >> /etc/hosts"
    sudo sh -c "echo $ipw3 worker-3.example.com worker-3 >> /etc/hosts"

	return 0
}

confirmConnectivity() {
for n in \
$(awk '/\<(master-1)\>/{print $3}' /etc/hosts) \
$(awk '/\<(master-2)\>/{print $3}' /etc/hosts) \
$(awk '/\<(worker-1)\>/{print $3}' /etc/hosts) \
$(awk '/\<(worker-2)\>/{print $3}' /etc/hosts) \
$(awk '/\<(worker-3)\>/{print $3}' /etc/hosts)
do
  echo $n
  if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 $n '/bin/true' 2>&1 > /dev/null
    then
    echo "ERROR: no response from $n; retry later."
    exit 1
  fi
done
}
# 2>&1 >> output.txt

copyHostsFile() {
  HOSTS=("master-1" "master-2" "worker-1" "worker-2" "worker-3")
  dialog --title "Copying the /etc/hosts files to the other instances." \
  --backtitle "Cluster Network Configuration" \
  --gauge "copying file to ..." 10 75 < <(
  # Get total number of hosts in array
  n=${#HOSTS[*]};

  # set counter - it will increase every-time a file is copied to $DEST
  i=0
   # Start the for loop
   # read each host from $HOSTS array
   # $h has hostname
   for h in "${HOSTS[@]}"
   do
      # calculate progress
      PCT=$(( 100*(++i)/n ))

      # update dialog box
cat <<EOF
XXX
$PCT
Copying file "$h"...
XXX
EOF
  # copy file $h to HOSTS
   scp /etc/hosts root@$h:/etc/hosts &> /dev/null
   sleep 2
   done
)
}

set_hostnames() {
  echo
  echo "Setting OS hostnames on masters and workers..."
  for i in master-1 master-2 worker-1 worker-2 worker-3 ; do ssh $nocheck training@$i sudo hostnamectl set-hostname $i && echo "$i .. Done"  ; done
  echo
  echo "Rebooting masters and workers..."
  for i in master-1 master-2 worker-1 worker-2 worker-3 ; do ssh $nocheck training@$i "sudo /usr/sbin/shutdown -r now" 2>&1; done
  echo
  echo "Waiting for the machines to come back up..."
  mustwait=0
  while [ $mustwait -eq 0 ]
    do
      m1=$(nmap master-1 | grep 22)
      m2=$(nmap master-2 | grep 22)
      w1=$(nmap worker-1 | grep 22)
      w2=$(nmap worker-2 | grep 22)
      w3=$(nmap worker-3 | grep 22)

      if [[ $m1 != "" && $m2 != "" && $w1 != "" && $w2 != "" && $w3 != "" ]]; then
        mustwait="1"
      else
        sleep 10
      fi
    done
}


MYHOST="`hostname`: "
# Avoid "sudo: cannot get working directory" errors by
# changing to a directory owned by the training user
cd ~
echo
echo $MYHOST "Running " $0"."
verify
removeCruft
fix_cmhost_hosts
updateHostsFile
confirmConnectivity  2>&1 >> $LOG_FILE
copyHostsFile
set_hostnames  | dialog --title "Setting OS hostnames on masters and workers" --backtitle "Cluster Network Configuration" --no-collapse --progressbox 10 100
#echo
#echo $MYHOST $0 "done."
dialog  --backtitle "Cluster Network Configuration" --no-collapse --infobox "\nScript has been successfully completed..." 5 70
sleep 2
clear

