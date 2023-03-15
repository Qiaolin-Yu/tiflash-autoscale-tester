-- using 1365545250 as a seed to the RNG


select /*+ read_from_storage(tiflash[supplier,nation]) */
	s_name,
	s_address
from
	supplier,
	nation
where
	s_suppkey in (
		select /*+ read_from_storage(tiflash[partsupp]) */
			ps_suppkey
		from
			partsupp
		where
			ps_partkey in (
				select /*+ read_from_storage(tiflash[part]) */
					p_partkey
				from
					part
				where
					p_name like 'green%'
			)
			and ps_availqty > (
				select /*+ read_from_storage(tiflash[lineitem]) */
					0.5 * sum(l_quantity)
				from
					lineitem
				where
					l_partkey = ps_partkey
					and l_suppkey = ps_suppkey
					and l_shipdate >= '1993-01-01'
					and l_shipdate < date_add('1993-01-01', interval '1' year)
			)
	)
	and s_nationkey = n_nationkey
	and n_name = 'ALGERIA'
order by
	s_name;
