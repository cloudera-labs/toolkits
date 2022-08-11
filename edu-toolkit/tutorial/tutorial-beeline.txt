# Grant unrestricted access to hive 
ssh centos@admin01
sudo su - hdfs
hdfs dfs -chmod 777 /warehouse/tablespace/external/hive

# Beeline connect
beeline -n hive -u "jdbc:hive2://client01.cloudair.lan:10000/default"


# Other users
beeline -n zeppelin -u "jdbc:hive2://client01.cloudair.lan:10000/default"
beeline -n akhan -u "jdbc:hive2://client01.cloudair.lan:10000/cloudair"
beeline -n prose -u "jdbc:hive2://client01.cloudair.lan:10000/cloudair"
beeline -n dsmith -u "jdbc:hive2://client01.cloudair.lan:10000/cloudair"

# With Ranger authorization
beeline -n horton -u "jdbc:hive2://client01.cloudair.lan:10000/default"

# With Kerberos installed
beeline -u "jdbc:hive2://client01.cloudair.lan:10000/default;principal=hive/client01.cloudair.lan/CLOUDAIR.LAN"
# If configured this shortcut should also work
beeline -u "jdbc:hive2://client01.cloudair.lan:10000/default;principal=hive/_HOST/CLOUDAIR.LAN"

# Connect
!connect

# Basic Commands
help 
!list
show databases;
use default;
show tables;
create table temp_drivers(col_value STRING);
show tables;
drop table temp_drivers;
show tables;
!quit

