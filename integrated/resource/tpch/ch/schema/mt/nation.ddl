CREATE TABLE IF NOT EXISTS nation (
	n_nationkey  Int32,
	n_name       String,
	n_regionkey  Int32,
	n_comment    Nullable(String)
) ENGINE = MergeTree()
order by (n_nationkey)
SETTINGS index_granularity = 8192 ;
