CREATE TABLE IF NOT EXISTS part(
	p_partkey     Int32,
	p_name        String,
	p_mfgr        String,
	p_brand       String,
	p_type        String,
	p_size        Int32,
	p_container   String,
	p_retailprice Decimal(15, 2),
	p_comment     String
) ENGINE = MutableMergeTree((p_partkey), 8192);
