CREATE TABLE IF NOT EXISTS partsupp(
    ps_partkey Int32, 
    ps_suppkey Int32, 
    ps_availqty Int32, 
    ps_supplycost Decimal(15, 2), 
    ps_comment String
)
ENGINE = DeltaMerge((ps_partkey, ps_suppkey))
