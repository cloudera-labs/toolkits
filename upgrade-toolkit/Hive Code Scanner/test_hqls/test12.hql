SELECT ACOS(0.25);
SELECT ASIN(0.25);
select corr(col1,col2)from function_t;
SELECT covar_samp(Annual_salary)) FROM employee_dimension;
select cast(123.000 as varchar(10));
select cast('1' as tinyint);
SELECT STDDEV_SAMP(total_cost) FROM purchase;
SELECT VAR_SAMP(total_cost) FROM purchase;
CREATE EXTERNAL TABLE t(a TINYINT, b SMALLINT NOT NULL ENABLE, c INT);
select CUSTOMER_ID,EMAIL_FAILURE_DTMZ,add_months(EMAIL_FAILURE_DTMZ , 1) from TABLE1 where CUSTOMER_ID=125674937;
select add_months('2017-02-29', 1);
SELECT FROM_UNIXTIME(946609199.999999) AS Result;
select current_timestamp() from all100k union select current_timestamp() from over100k limit 5;
select length(abs('99.000'));
SELECT UNIX_TIMESTAMP('2022-01-27 16:11:27', "yyyy-MM-dd hh:mm:ss"), FROM_UTC_TIMESTAMP(FROM_UNIXTIME(UNIX_TIMESTAMP('2022-01-27 16:11:27', "yyyy-MM-dd hh:mm:ss"),'yyyy-MM-dd HH:mm:ss'), 'CST'), FROM_UTC_TIMESTAMP(FROM_UNIXTIME(UNIX_TIMESTAMP('2022-01-27T16:11:27.192+0000', "yyyy-MM-dd'T'hh:mm:ss.SSS'+0000'"),'yyyy-MM-dd HH:mm:ss'), 'CST');
select unix_timestamp('11-11-2020 15:30:12.084','MM-dd-yyyy HH:mm:ss');
SELECT CAST ('0000-00-00' as date) , CAST ('000-00-00 00:00:00' AS TIMESTAMP);
Set hive.txn.xlock.mergeinsert=true
select distinct acct_no , pre_staging from cnt_1h_srvy_sec.atm_onscreen_survey_interm where acct_no =  '5175729100088766' order by pre_staging desc;
select coalesce(5.0,'EMPTY') <> coalesce(5,'EMPTY');
select cast(unix_timestamp('2023-04-03:10:10:00', 'yyyyMM') as string);
select cast(cast(1.1 as decimal(22, 2)) as string);;
SELECT DATE_ADD("2017-06-15", INTERVAL 10 DAY);
SELECT DATE_SUB("2017-06-15", INTERVAL 10 DAY);
select date_format('1001-01-05','dd---MM--yyyy');

