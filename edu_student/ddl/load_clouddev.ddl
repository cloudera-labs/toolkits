-- load data into clouddev_stage and clouddev

USE clouddev_stage;

LOAD DATA INPATH '/warehouse/tablespace/data/clouddev/consent_data.csv'  INTO TABLE clouddev_stage.consent_data;

LOAD DATA INPATH '/warehouse/tablespace/data/clouddev/eu_country.csv' INTO TABLE clouddev_stage.eu_country;

LOAD DATA INPATH '/warehouse/tablespace/data/clouddev/us_customer.csv' INTO TABLE clouddev_stage.us_customer;

LOAD DATA INPATH '/warehouse/tablespace/data/clouddev/ww_customer.csv' INTO TABLE clouddev_stage.ww_customer;

SELECT * FROM clouddev_stage.eu_country LIMIT 3;
SELECT * FROM clouddev_stage.ww_customer LIMIT 3;

INSERT INTO TABLE clouddev.consent_data SELECT * FROM clouddev_stage.consent_data;

INSERT INTO TABLE clouddev.eu_country SELECT * FROM clouddev_stage.eu_country;

INSERT INTO TABLE clouddev.us_customer SELECT * FROM clouddev_stage.us_customer;

INSERT INTO TABLE clouddev.ww_customer SELECT * FROM clouddev_stage.ww_customer;

USE cloudev;

SELECT * FROM clouddev.eu_country LIMIT 3;
SELECT * FROM clouddev.ww_customer LIMIT 3;

