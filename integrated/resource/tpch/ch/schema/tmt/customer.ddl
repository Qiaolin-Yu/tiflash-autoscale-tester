CREATE TABLE IF NOT EXISTS customer (
	c_custkey     Int32,
	c_name        String,
	c_address     String,
	c_nationkey   Int32,
	c_phone       String,
	c_acctbal     Decimal(15, 2),
	c_mktsegment  String,
	c_comment     String
) ENGINE = MutableMergeTree((c_custkey), 8192);
