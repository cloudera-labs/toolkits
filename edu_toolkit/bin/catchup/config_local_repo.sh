#!/bin/bash

# This script will configure CM local repository on worker-3 http served. 

main () {

# Install AWS CLI tool
aws --version
if [[ $(echo $?) == 0 ]]; then 
  echo "aws CLI tool is already instlled"
else 
  echo "Installing AWS CLI tool"
  cd /tmp/
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
fi

# Install, configure, start and enable httpd 
sudo yum install httpd -y 
sudo sed -i 's/"Listen 80"/"Listen 8060"/g' /etc/httpd/conf/httpd.conf
sudo systemctl start httpd
sudo systemctl enable httpd

# Manage CM installation packages 
sudo aws s3 cp s3://admin-public/cloudera-parcels/cm7/cm7.1.3-redhat7.tar.gz /var/www/html/cloudera-repos/cm7/
sudo tar xvfz /var/www/html/cloudera-repos/cm7/cm7.1.3-redhat7.tar.gz -C /var/www/html/cloudera-repos/cm7 --strip-components=1
sudo chmod -R ugo+rX /var/www/html/cloudera-repos/cm7

# Manage CFM Parcels 
sudo aws s3 cp s3://admin-public/cloudera-parcels/CFM/CFM-2.0.1.0-71-el7.parcel /var/www/html/cloudera-repos/CFM/
sudo aws s3 cp s3://admin-public/cloudera-parcels/CFM/CFM-2.0.1.0-71-el7.parcel.sha /var/www/html/cloudera-repos/CFM/
sudo aws s3 cp s3://admin-public/cloudera-parcels/CFM/manifest.json /var/www/html/cloudera-repos/CFM/

# Manage CDP 7.1.2 Parcels 
sudo aws s3 cp s3://admin-public/cloudera-parcels/7.1.2/CDH-7.1.2-1.cdh7.1.2.p0.4253134-el7.parcel /var/www/html/cloudera-repos/7.1.2/
sudo aws s3 cp s3://admin-public/cloudera-parcels/7.1.2/CDH-7.1.2-1.cdh7.1.2.p0.4253134-el7.parcel.sha /var/www/html/cloudera-repos/7.1.2/
sudo aws s3 cp s3://admin-public/cloudera-parcels/7.1.2/manifest.json /var/www/html/cloudera-repos/7.1.2/


# Manage CDP 7.1.3 Parcels 
sudo aws s3 cp s3://admin-public/cloudera-parcels/7.1.3/manifest.json /var/www/html/cloudera-repos/7.1.3/
sudo aws s3 cp s3://admin-public/cloudera-parcels/7.1.3/CDH-7.1.3-1.cdh7.1.3.p0.4992530-el7.parcel /var/www/html/cloudera-repos/7.1.3/
sudo aws s3 cp s3://admin-public/cloudera-parcels/7.1.3/CDH-7.1.3-1.cdh7.1.3.p0.4992530-el7.parcel.sha /var/www/html/cloudera-repos/7.1.3/


sudo chmod -R ugo+rX /var/www/html/cloudera-repos/
sudo systemctl restart httpd.service 
echo "restarting httpd service"
sleep 10

#####  Test new Repo URL #######
# From a cmhost, start a web browser and enter this URL:
# http://worker-3:8060/cloudera-repos/
# http://worker-3:8060/cloudera-repos/cm7/
# http://worker-3:8060/cloudera-repos/7.1.2/
# http://worker-3:8060/cloudera-repos/7.1.3/
# If you can’t access the above URLs, make sure /etc/hosts file has worker-3 included
}

if [ -z "$(ls -A /var/www/html/cloudera-repos)" ]; then
   echo "Cloudera-repos directory is Empty"
   main
else
   echo "Cloudera-repo is Not Empty, continue.."
fi


if curl --head --silent --fail http://worker-3:8060/cloudera-repos/ 2> /dev/null;
 then
  echo "Local repo is OK."
 else
  echo "Local repo is KO, Please check http service on worker-3."
fi
