#!/bin/bash
cd /home/training/config

setup(){
	rm -rf /home/training/config/working
	mkdir /home/training/config/working
	cp /home/training/config/addCMS.json /home/training/config/working/addCMS.json
}

gather_info(){
	curl -s -X GET -H "Content-Type:application/json" -u admin:admin http://cmhost:7180/api/v10/hosts|grep 'hostId\|ipAddress\|hostname' > /home/training/config/CMhostInfo.txt
	
	sed -i 's/"//g' /home/training/config/CMhostInfo.txt
	sed -i 's/,//g' /home/training/config/CMhostInfo.txt

	newHostID=$(cat /home/training/config/CMhostInfo.txt | sed -n 1p | awk '{print $3}')
	newIP=$(cat /home/training/config/CMhostInfo.txt | sed -n 2p | awk '{print $3}')
	newHostname=$(cat /home/training/config/CMhostInfo.txt | sed -n 3p | awk '{print $3}')
}

add_mgmt_services(){

	curl -s -X POST -H "Content-Type:application/json" -u admin:admin http://cmhost:7180/api/v10/cm/trial/begin

	sudo sed -i "s/replace-host-id/$newHostID/g" /home/training/config/working/addCMS.json
	sudo sed -i "s/replace-ip-addr/$newIP/g" /home/training/config/working/addCMS.json
	sudo sed -i "s/replace-hostname/$newHostname/g" /home/training/config/working/addCMS.json

	echo 
	echo "deploying Cloudera Management Service to cmhost"
	curl -s -X PUT -H "Content-Type:application/json" -u admin:admin http://cmhost:7180/api/v10/cm/deployment -d @/home/training/config/working/addCMS.json
	sleep 5
	echo 
	echo "starting Cloudera Management service"
	curl -s -X POST -H "Content-Type:application/json" -u admin:admin http://cmhost:7180/api/v10/cm/service/commands/start
    ##### Verify CMS first start #####
    procId=$(echo $startCMS | awk '{print $4}' | sed 's/,//')
    sleep 20 
    #verify status
    xvResp=0
    xcount=0
    ycount=0
    while [ $xvResp -eq 0 ]
    do
        #wait for the CMS startup to complete before importing the CM template
        status=$(curl -s -X GET -H "Content-Type:application/json" -u admin:admin http://localhost:7180/api/v1/commands/$procId |grep active)
        s1=$(echo $status |awk '{print $3}'|sed s/,//)

        if [[ "$s1" == "false" ]]; then
            printf "\n"

            # If CMS does not start after 45 secs, exit out.
            if [[ $ycount -ge 45 ]]; then
                echo "********************************************************************************"
                echo ""
                echo "There is a problem in reset_cluster when starting CMS."
                echo "Please run reset_cluster.sh again."
                echo "Exiting."
                echo
                echo "********************************************************************************"
                exit
            else
                ycount=$(( $ycount +1))
            fi


            echo "CMS startup command has completed. Verifying successful startup."
            echo
            #check if the startup succeeded
            tresult=$(curl -s -X GET -H "Content-Type:application/json" -u admin:admin http://localhost:7180/api/v1/commands/$procId |grep '"success"')
            t1=$(echo $tresult |awk '{print $3}'|sed s/,// )

            if [[ "$t1" == "true" ]]; then
                echo "Cloudera Management Service startup was successful. "
                echo
                xvResp=1
            else
                echo
                echo "ERROR: The CMS service did not start up successfully."
                echo
               exit 1
            fi
        else
            #Startup is still in progress
            xcount=0
            while [ $xcount -lt 15 ];
            do
                xcount=$(( $xcount +1 ))
                printf "."
      
          exit 
          sleep 1
            done
       fi
    done
}


setup 
gather_info
add_mgmt_services
