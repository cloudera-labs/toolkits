# Get SCSI Info
lshw -c storage -c disk > /tmp/disk_info.txt
cat /tmp/disk_info.txt | grep -i "nfs" > /tmp/scsi_info.txt
[ -s /tmp/scsi_info.txt ] && echo "not all devices are scsi" || echo "all devices are scsi"