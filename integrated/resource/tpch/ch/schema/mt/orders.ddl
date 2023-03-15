CREATE TABLE IF NOT EXISTS orders (
	o_orderkey       Int32,
	o_custkey        Int32,
	o_orderstatus    String,
	o_totalprice     Decimal(15, 2),
	o_orderdate      Date,
	o_orderpriority  String,
	o_clerk          String,
	o_shippriority   Int32,
	o_comment        String
) ENGINE = MergeTree()
order by (o_orderkey)
SETTINGS index_granularity = 8192 ;
