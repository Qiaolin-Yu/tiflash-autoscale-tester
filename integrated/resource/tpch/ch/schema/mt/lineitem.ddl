CREATE TABLE IF NOT EXISTS lineitem (
    l_orderkey    Int32,
    l_partkey     Int32,
    l_suppkey     Int32,
    l_linenumber  Int32,
    l_quantity    Float64,
    l_extendedprice  Float64,
    l_discount    Float64,
    l_tax         Float64,
    l_returnflag  FixedString(1),
    l_linestatus  FixedString(1),
    l_shipdate    Date,
    l_commitdate  Date,
    l_receiptdate Date,
    l_shipinstruct String,
    l_shipmode     String,
    l_comment      String
) ENGINE = MergeTree()
order by (l_orderkey, l_linenumber)
SETTINGS index_granularity = 8192 ;
