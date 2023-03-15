CREATE TABLE IF NOT EXISTS lineitem (
	l_orderkey    Int32,
	l_partkey     Int32,
	l_suppkey     Int32,
	l_linenumber  Int32,
	l_quantity    Decimal(15, 2),
	l_extendedprice  Decimal(15, 2),
	l_discount    Decimal(15, 2),
	l_tax         Decimal(15, 2),
	l_returnflag  String,
	l_linestatus  String,
	l_shipdate    Date,
	l_commitdate  Date,
	l_receiptdate Date,
	l_shipinstruct String,
	l_shipmode     String,
	l_comment      String
) ENGINE = MutableMergeTree((l_orderkey, l_linenumber), 8192);
