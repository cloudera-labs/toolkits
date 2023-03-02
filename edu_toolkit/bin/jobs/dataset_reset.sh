#!/bin/bash

##############################################################
##               DATASET AND TABLES CLEANUP                 ##
##############################################################
dataAndTablesCleanUp () {
        echo "#####################################"
        echo "Drop ngrams External Hive table."
        echo "#####################################"
        beeline -u jdbc:hive2://master-2:10000 -n training -e "DROP TABLE ngrams;"
         
        echo "#####################################"
        echo "Drop ngrams_gz External Hive table."
        echo "#####################################"
        beeline -u jdbc:hive2://master-2:10000 -n training -e "DROP TABLE ngrams_zipped;"
  
        echo "#####################################"
        echo "DataSet Cleanup"
        echo "#####################################"
        sudo -u hdfs hdfs dfs -rm -r -skipTrash /warehouse/tablespace/external/hive/ngrams
        sudo -u hdfs hdfs dfs -rm -r -skipTrash /warehouse/tablespace/external/hive/ngrams_zipped
        sudo -u hdfs hdfs dfs -rm -r -skipTrash /user/training
        sudo -u hdfs hdfs dfs -rm -r -skipTrash /weblogs
        sudo -u hdfs hdfs dfs -rm -r -skipTrash /tmp/ngrams
        sudo -u hdfs hdfs dfs -rm -r -skipTrash /tmp/ngrams_gz
        sudo -u hdfs hdfs dfs -rm -r -skipTrash /tmp/moviedata

}

##############################################################
##                              HDFS FUNCTIONS              ##
##############################################################
exerciseHDFS () {
        echo "#####################################"
        echo "Creating /user/training dir in HDFS."
        echo "#####################################"
        sudo -u hdfs hdfs dfs -mkdir -p /user/training
        sudo -u hdfs hdfs dfs -chown training /user/training

        echo "#####################################"
        echo "Creating /weblogs dir in HDFS."
        echo "#####################################"
        sudo -u hdfs hdfs dfs -mkdir /weblogs
        sudo -u hdfs hdfs dfs -chown training /weblogs

        echo "#####################################"
        echo "Uploading access_log to /weblogs dir in HDFS."
        echo "#####################################"
        cd ~/training_materials/admin/data
        gunzip access_log.gz
        hdfs dfs -put ~/training_materials/admin/data/weblogs* /weblogs/

        echo "#####################################"
        echo "Uploading Google Ngrams Dataset *[a-e] to /tmp/ngrams dir in HDFS."
        echo "#####################################"
        hdfs dfs -mkdir /tmp/ngrams
        hdfs dfs -put /ngrams/unzipped/*[a-e] /tmp/ngrams/
        
        echo "#####################################"
        echo "Uploading Google Ngrams Dataset *[a-e] to /tmp/ngrams_gz dir in HDFS."
        echo "#####################################"
        hdfs dfs -mkdir /tmp/ngrams_gz
        hdfs dfs -put /ngrams/gz/*[a-e].gz /tmp/ngrams_gz/

        echo "#####################################"
        echo "Uploading shakespeare.txt Dataset /user/training dir in HDFS."
        echo "#####################################"
        gunzip ~/training_materials/admin/data/shakespeare.txt.gz
        hdfs dfs -put ~/training_materials/admin/data/shakespeare.txt /user/training
}


##############################################################
##                   SQOOP                                  ##
##############################################################
importTablesSqoop () {
        
        sudo rm -rf /tmp/sqoop-training
        sudo -u hdfs hdfs dfs -rm -r -skipTrash /tmp/moviedata
        #import movie table into hadoop
        echo "#####################################"
        echo "Importing movie table into hadoop."
        echo "#####################################"
        hdfs dfs -mkdir /tmp/moviedata
        sqoop import \
        --connect jdbc:mysql://cmhost/movielens \
        --username training --password training \
        --table movie --fields-terminated-by '\t' \
        --target-dir /tmp/moviedata/movie

        #sqoop import \
        #--connect jdbc:mysql://localhost/movielens \
        #--table movie --fields-terminated-by '\t' \
        #--username training --password training

        #verify command worked
        echo "#####################################"
        echo "Displaying end of movie table in HDFS."
        echo "#####################################"
        hdfs dfs -ls /tmp/moviedata/movie
        hdfs dfs -tail /tmp/moviedata/movie/part-m-00000

        #import movierating table into hadoop
        echo "#####################################"
        echo "Importing movierating table into hadoop."
        echo "#####################################"
        sqoop import \
       --connect jdbc:mysql://cmhost/movielens \
       --username training --password training \
       --table movierating --as-parquetfile \
       --target-dir /tmp/moviedata/movierating

        #sqoop import \
        #--connect jdbc:mysql://localhost/movielens \
        #--table movierating --fields-terminated-by '\t' \
        #--username training --password training

        #verify command worked
        echo "#####################################"
        echo "Testing movierating table is now in hadoop."
        echo "#####################################"
        hdfs dfs -ls /tmp/moviedata/movierating

        #see apps finished (should include sqoop MR jobs)
        echo "#####################################"
        echo "Display finished yarn jobs."
        echo "#####################################"
        yarn application -list -appStates FINISHED
}

##############################################################
##           "Working with Hive and Impala"                 ##
##############################################################
exerciseWorkingWithHiveAndImpala () {
        echo "#####################################"
        echo "Create ngrams EXTERNAL hive table."
        echo "#####################################"
        beeline -u jdbc:hive2://master-2:10000 -n training -e "CREATE \
        EXTERNAL TABLE ngrams (gram string, year int, occurrences \
        bigint, pages bigint, books bigint) ROW FORMAT DELIMITED \
        FIELDS TERMINATED BY '\t'"
        
        echo "#####################################"
        echo "Load data into ngrams table."
        echo "#####################################"
        sudo -u hdfs hdfs dfs -chown hive /tmp/ngrams
        beeline -u jdbc:hive2://master-2:10000 -n training -e "LOAD \
        DATA INPATH '/tmp/ngrams/' INTO TABLE ngrams"

#        beeline -u jdbc:hive2://master-2:10000 -n training -e "SELECT * FROM ngrams WHERE gram='computer';"

#        hdfs dfs -mkdir /tmp/ngrams_gz
#        hdfs dfs -put /ngrams/gz/*[a-e].gz /tmp/ngrams_gz/
        echo "#####################################"
        echo "Create ngrams_zipped EXTERNAL hive table."
        echo "#####################################"
        beeline -u jdbc:hive2://master-2:10000 -n training -e \
        "CREATE EXTERNAL TABLE ngrams_zipped (gram string, year int, \
        occurrences bigint, pages bigint, books bigint) ROW FORMAT \
        DELIMITED FIELDS TERMINATED BY '\t'"

        echo "#####################################"
        echo "Load data into ngrams_gz table."
        echo "#####################################"
        sudo -u hdfs hdfs dfs -chown hive /tmp/ngrams_gz
        beeline -u jdbc:hive2://master-2:10000 -n training -e "LOAD \
        DATA INPATH '/tmp/ngrams_gz/' INTO TABLE ngrams_zipped"
 
        echo "#####################################"
        echo "List Hive Tables"
        echo "#####################################"
        beeline -u jdbc:hive2://master-2:10000 -n training -e "show tables;"
 
        echo "#####################################"
        echo "List data from ngrams Hive Table"
        echo "#####################################"
        beeline -u jdbc:hive2://master-2:10000 -n training -e "SELECT * FROM ngrams LIMIT 10;"

        echo "#####################################"
        echo "List data from ngrams_zipped Hive Table"
        echo "#####################################"
        beeline -u jdbc:hive2://master-2:10000 -n training -e "SELECT * FROM ngrams_zipped LIMIT 10;"
}



dataAndTablesCleanUp
exerciseHDFS
importTablesSqoop
exerciseWorkingWithHiveAndImpala
