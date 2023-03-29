create database config;
use config;
create table t (a int, b int);
alter table t set tiflash replica 1;
insert into t values (1, 1), (2, 2), (3, 3), (4, 4), (5, 5);
create database config;
use config;
create table `config_0` (
  `id` int(11)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
insert into `config_0` values (1);
insert into `config_0` select * from config_0;
insert into `config_0` select * from config_0;
insert into `config_0` select * from config_0;
insert into `config_0` select * from config_0;
insert into `config_0` select * from config_0;
insert into `config_0` select * from config_0;
insert into `config_0` select * from config_0;
insert into `config_0` select * from config_0;
insert into `config_0` select * from config_0;
insert into `config_0` select * from config_0;
insert into `config_0` select * from config_0;
insert into `config_0` select * from config_0;
insert into `config_0` select * from config_0;
insert into `config_0` select * from config_0;
insert into `config_0` select * from config_0;
insert into `config_0` select * from config_0;
insert into `config_0` select * from config_0;
insert into `config_0` select * from config_0;
insert into `config_0` select * from config_0;
split table config_0 between (0) and (30000) regions 20;
insert into `config_0` values (2);
alter table config_0 set tiflash replica 1;

select * from information_schema.tiflash_replica;

ALTER TABLE gharchive_dev.github_events SET TIFLASH REPLICA 1;

SELECT *
FROM information_schema.tiflash_replica
WHERE TABLE_SCHEMA = 'gharchive_dev'
  AND TABLE_NAME = 'github_events';

SELECT UPPER(u.country_code) AS country_or_area,
       COUNT(DISTINCT actor_login) AS cnt
FROM gharchive_dev.github_events
LEFT JOIN gharchive_dev.users u ON gharchive_dev.github_events.actor_login = u.login
WHERE repo_name = 'kubernetes/kubernetes'
  AND gharchive_dev.github_events.type = 'PullRequestEvent'
  AND u.country_code IS NOT NULL
GROUP BY country_or_area
ORDER BY cnt DESC;

EXPLAIN ANALYZE
SELECT UPPER(u.country_code) AS country_or_area,
       COUNT(DISTINCT actor_login) AS cnt
FROM gharchive_dev.github_events
LEFT JOIN gharchive_dev.users u ON gharchive_dev.github_events.actor_login = u.login
WHERE repo_name = 'kubernetes/kubernetes'
  AND gharchive_dev.github_events.type = 'PullRequestEvent'
  AND u.country_code IS NOT NULL
GROUP BY country_or_area
ORDER BY cnt DESC;