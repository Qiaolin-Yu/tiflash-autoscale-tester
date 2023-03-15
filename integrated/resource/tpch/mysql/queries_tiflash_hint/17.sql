-- using 1365545250 as a seed to the RNG


select /*+ read_from_storage(tiflash[lineitem,part]) */
	sum(l_extendedprice) / 7.0 as avg_yearly
from
	lineitem,
	part
where
	p_partkey = l_partkey
	and p_brand = 'Brand#44'
	and p_container = 'WRAP PKG'
	and l_quantity < (
		select /*+ read_from_storage(tiflash[lineitem]) */
			0.2 * avg(l_quantity)
		from
			lineitem
		where
			l_partkey = p_partkey
	);
