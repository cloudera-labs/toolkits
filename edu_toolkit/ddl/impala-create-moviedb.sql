-- create Hive/Impala tables

DROP TABLE IF EXISTS movie_hive;

CREATE EXTERNAL TABLE movie_hive (
    id INT,
    name STRING,
    year INT) 
     ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t';

DROP TABLE IF EXISTS movierating_hive;

CREATE EXTERNAL TABLE movierating_hive (
  userid INT,
  movieid INT,
  rating INT)
  ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t';

-- create Kudu tables based on Impala tables
DROP TABLE IF EXISTS movie_kudu;

CREATE TABLE movie_kudu 
PRIMARY KEY(id)
PARTITION BY HASH(id) PARTITIONS 2
STORED AS KUDU
AS SELECT * FROM movie_hive;

DROP TABLE IF EXISTS movierating_kudu;

CREATE TABLE movierating_kudu 
PRIMARY KEY(movieid,userid)
PARTITION BY HASH(movieid) PARTITIONS 2
STORED AS KUDU
AS SELECT movieid,userid,rating FROM movierating_hive;