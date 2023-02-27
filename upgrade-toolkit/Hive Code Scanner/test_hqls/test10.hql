-- This test case contains mixed usage of deprecated configurations, keyword restrictions, and table operations

-- Deprecated Configuration
set hive.limit.query.max.table.partition=10;

-- Keyword restriction, line 7 should be captured for time
SELECT application_id, time, numeric_value FROM default.application_metrics;

--Keyword restriction, line 10 should be captured for application
SELECT application, time_line, numeric_value FROM default.application_metrics;

--Keyword restriction, line 13 should be captured for numeric
SELECT application_id, time_line, numeric FROM default.application_metrics;

--Keyword restriction, line 16 should be captured for sync
SELECT sync FROM default.application_metrics;


-- Deprecated Configuration
set hive.warehouse.subdir.inherit.perms=true;

-- Table operation
CREATE TABLE default.`application_metrics_v2` AS SELECT * FROM default.application_metrics;

-- Deprecated Configuration
set hive.stats.fetch.partition.stats=true;

-- Keyword restriction
SELECT sync_time, sync_status FROM default.application_metrics_v2;
