#!/bin/bash
installCM() {
echo 
echo "*********************************************"
echo ">>>Running mysql-setup.sql"
echo "*********************************************"
mysql -u root -ptraining < /home/training/training_materials/admin/scripts/mysql-setup.sql

echo
echo "*********************************************"
echo ">>>Calling mysql_secure_installation."
echo "*********************************************"
expect -c "set timeout -1
spawn sudo /usr/bin/mysql_secure_installation
expect -re \"Enter *\"
send \"training\r\"
expect -re \"Set *\"
send \"Y\r\"
expect -re \"New *\"
send \"training\r\"
expect -re \"Re-enter *\"
send \"training\r\"
expect -re \"Remove *\"
send \"Y\r\"
expect -re \"Disallow *\"
send \"Y\r\"
expect -re \"Remove *\"
send \"Y\r\"
expect -re \"Reload *\"
send \"Y\r\"
expect eof"

echo "*********************************************"
echo ">>>Restaring MySql service..."
echo "*********************************************"
sudo systemctl restart mysqld

echo "*********************************************"
echo ">>>Installing CM Server and Daemons..."
echo "*********************************************"
cd /home/training/software/713/RPMS/x86_64
#sudo yum localinstall -y cloudera-manager-server* cloudera-manager-daemon*
sudo yum localinstall -y cloudera-manager-server-7.1.3-4999720.el7.x86_64.rpm  cloudera-manager-daemons-7.1.3-4999720.el7.x86_64.rpm


echo 
echo "*********************************************"
echo ">>>Setting CM server service to off"
echo "*********************************************"
sudo systemctl disable cloudera-scm-server > /dev/null 2>&1
echo
echo "*********************************************"
echo ">>>Preparing the CM database"
echo "*********************************************"
echo
sudo /opt/cloudera/cm/schema/scm_prepare_database.sh mysql cmserver cmserveruser password
echo "done"
sleep 2

echo 
echo "*********************************************"
echo ">>>Starting CM server"
echo "*********************************************"
sudo systemctl start cloudera-scm-server.service
sleep 5
#Configure Cloudera Manager server service to start at boot

echo 
echo "*********************************************"
echo ">>>Check CM server service status"
echo "*********************************************"
check=$(sudo systemctl status cloudera-scm-server | grep Active: | cut -d " " -f5)

if [[ "$check" != "failed" ]]; then 
	echo "CM Server installation checks OK"
fi  

echo 
echo "*********************************************"
echo ">>>Setting CM Server to start at system boot..."
echo "*********************************************"
sudo systemctl enable cloudera-scm-server  > /dev/null 2>&1


echo "Done."
echo 
}

installCM | dialog --clear --title "Install and configure CM server" --backtitle "Install CM Server" --no-collapse --progressbox 20 100
