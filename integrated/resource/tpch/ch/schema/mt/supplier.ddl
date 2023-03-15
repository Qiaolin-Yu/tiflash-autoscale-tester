CREATE TABLE IF NOT EXISTS supplier (
	s_suppkey     Int32,
	s_name        String,
	s_address     String,
	s_nationkey   Int32,
	s_phone       String,
	s_acctbal     Decimal(15, 2),
	s_comment     String
) ENGINE = MergeTree()
order by (s_suppkey)
SETTINGS index_granularity = 8192 ;
