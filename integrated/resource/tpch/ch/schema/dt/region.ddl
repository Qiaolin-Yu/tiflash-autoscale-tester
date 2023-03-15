CREATE TABLE IF NOT EXISTS region
(
    r_regionkey Int32, 
    r_name String, 
    r_comment Nullable(String)
)
ENGINE = DeltaMerge(r_regionkey)
