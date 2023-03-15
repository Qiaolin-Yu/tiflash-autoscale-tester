CREATE TABLE IF NOT EXISTS nation (
	n_nationkey  Int32,
	n_name       String,
	n_regionkey  Int32,
	n_comment    Nullable(String)
) ENGINE = MutableMergeTree((n_nationkey), 8192);
