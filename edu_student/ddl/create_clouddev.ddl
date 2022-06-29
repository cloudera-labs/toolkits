-- ddl for clouddev

DROP DATABASE IF EXISTS clouddev_stage CASCADE;

CREATE DATABASE clouddev_stage;
USE clouddev_stage;

DROP TABLE IF EXISTS clouddev_stage.consent_data;

CREATE EXTERNAL TABLE IF NOT EXISTS clouddev_stage.consent_data(
  country_code STRING,
  country STRING,
  insurance_id INT,
  marketing_consent STRING,
  marketing_consent_start_date DATE,
  loyalty_consent STRING,
  loyalty_consent_start_date DATE,
  third_party_consent STRING,
  third_party_consent_start_date DATE)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
LOCATION '/warehouse/tablespace/external/hive/clouddev_stage.db/consent_data';

ALTER TABLE clouddev_stage.consent_data
SET TBLPROPERTIES ("skip.header.line.count"="1");

DROP TABLE IF EXISTS clouddev_stage.eu_country;

CREATE EXTERNAL TABLE clouddev_stage.eu_country(
  country_name STRING,
  country_code STRING,
  region STRING)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
LOCATION '/warehouse/tablespace/external/hive/clouddev_stage.db/eu_country';

ALTER TABLE clouddev_stage.eu_country
SET TBLPROPERTIES ("skip.header.line.count"="1");

DROP TABLE IF EXISTS clouddev_stage.us_customer;

CREATE EXTERNAL TABLE clouddev_stage.us_customer(
    customer_id INT,
    gender STRING,
    title STRING,
    first_name STRING,
    middle_initial STRING,
    last_name STRING,
    address STRING,
    city STRING,
    state_code STRING,
    state STRING,
    zip_code STRING,
    country_code STRING,
    country STRING,
    email STRING,
    username STRING,
    password STRING,
    telephone STRING,
    telephone_country_code STRING,
    mother_maiden STRING,
    birthday DATE,
    age INT,
    tropical_zodiac STRING,
    cc_type STRING,
    cc_number STRING,
    cvv2 INT,
    cc_expires DATE,
    national_id STRING,
    mrn STRING,
    insurance_id INT,
    eye_color STRING,
    occupation STRING,
    company STRING,
    vehicle STRING,
    domain STRING,
    blood_type STRING,
    weight NUMERIC (6, 2),
    height NUMERIC (6, 2),
    latitude NUMERIC (12, 8),
    longitude NUMERIC (12, 8))
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
LOCATION '/warehouse/tablespace/external/hive/clouddev_stage.db/us_customer';

ALTER TABLE clouddev_stage.us_customer
SET TBLPROPERTIES ("skip.header.line.count"="1");

DROP TABLE IF EXISTS clouddev_stage.ww_customer;

CREATE EXTERNAL TABLE clouddev_stage.ww_customer(
    customer_id INT,
    title STRING,
    first_name STRING,
    middle_initial STRING,
    last_name STRING,
    name_set STRING,
    address STRING,
    city STRING,
    state_code STRING,
    state STRING,
    zip_code STRING,
    country_code STRING,
    country STRING,
    telephone_country_code STRING,
    telephone STRING,
    email STRING,
    username STRING,
    password STRING,
    national_id STRING,
    mrn STRING,
    insurance_id INT,
    cc_type STRING,
    cc_number STRING,
    cvv2 INT,
    cc_expires STRING,
    occupation STRING,
    company STRING,
    domain STRING,
    vehicle STRING,
    gender STRING,
    mothers_maiden STRING,
    birthday STRING,
    tropical_zodiac STRING,
    age INT,
    eye_color STRING,
    blood_type STRING,
    weight NUMERIC (6, 2),
    height NUMERIC (6, 2),
    latitude NUMERIC (12, 8),
    longitude NUMERIC (12, 8))
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
LOCATION '/warehouse/tablespace/external/hive/clouddev_stage.db/ww_customer';

ALTER TABLE clouddev_stage.ww_customer
SET TBLPROPERTIES ("skip.header.line.count"="1");

DROP DATABASE IF EXISTS clouddev CASCADE;

CREATE DATABASE IF NOT EXISTS clouddev;
USE clouddev;

DROP TABLE IF EXISTS clouddev.consent_data;

CREATE TABLE IF NOT EXISTS clouddev.consent_data(
  country_code STRING,
  country STRING,
  insurance_id INT,
  marketing_consent STRING,
  marketing_consent_start_date DATE,
  loyalty_consent STRING,
  loyalty_consent_start_date DATE,
  third_party_consent STRING,
  third_party_consent_start_date DATE);

DROP TABLE IF EXISTS clouddev.eu_country;

CREATE TABLE clouddev.eu_country(
  country_name STRING,
  country_code STRING,
  region STRING);

DROP TABLE IF EXISTS clouddev.us_customer;

CREATE TABLE clouddev.us_customer(
    customer_id INT,
    gender STRING,
    title STRING,
    first_name STRING,
    middle_initial STRING,
    last_name STRING,
    address STRING,
    city STRING,
    state_code STRING,
    state STRING,
    zip_code STRING,
    country_code STRING,
    country STRING,
    email STRING,
    username STRING,
    password STRING,
    telephone STRING,
    telephone_country_code STRING,
    mother_maiden STRING,
    birthday DATE,
    age INT,
    tropical_zodiac STRING,
    cc_type STRING,
    cc_number STRING,
    cvv2 INT,
    cc_expires DATE,
    national_id STRING,
    mrn STRING,
    insurance_id INT,
    eye_color STRING,
    occupation STRING,
    company STRING,
    vehicle STRING,
    domain STRING,
    blood_type STRING,
    weight NUMERIC (6, 2),
    height NUMERIC (6, 2),
    latitude NUMERIC (12, 8),
    longitude NUMERIC (12, 8));

DROP TABLE IF EXISTS clouddev.ww_customer;

CREATE TABLE clouddev.ww_customer(
    customer_id INT,
    title STRING,
    first_name STRING,
    middle_initial STRING,
    last_name STRING,
    name_set STRING,
    address STRING,
    city STRING,
    state_code STRING,
    state STRING,
    zip_code STRING,
    country_code STRING,
    country STRING,
    telephone_country_code STRING,
    telephone STRING,
    email STRING,
    username STRING,
    password STRING,
    national_id STRING,
    mrn STRING,
    insurance_id INT,
    cc_type STRING,
    cc_number STRING,
    cvv2 INT,
    cc_expires STRING,
    occupation STRING,
    company STRING,
    domain STRING,
    vehicle STRING,
    gender STRING,
    mothers_maiden STRING,
    birthday STRING,
    tropical_zodiac STRING,
    age INT,
    eye_color STRING,
    blood_type STRING,
    weight NUMERIC (6, 2),
    height NUMERIC (6, 2),
    latitude NUMERIC (12, 8),
    longitude NUMERIC (12, 8));

USE clouddev_stage;
SHOW TABLES;

USE clouddev;
SHOW TABLES;


