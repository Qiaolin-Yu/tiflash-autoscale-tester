-- using 1365545250 as a seed to the RNG

drop view if exists revenue0;
create view revenue0 (supplier_no, total_revenue) as
	select /*+ read_from_storage(tiflash[lineitem]) */
		l_suppkey,
		sum(l_extendedprice * (1 - l_discount))
	from
		lineitem
	where
		l_shipdate >= '1997-07-01'
		and l_shipdate < date_add('1997-07-01', interval '3' month)
	group by
		l_suppkey;


select /*+ read_from_storage(tiflash[supplier,revenue0]) */
	s_suppkey,
	s_name,
	s_address,
	s_phone,
	total_revenue
from
	supplier,
	revenue0
where
	s_suppkey = supplier_no
	and total_revenue = (
		select /*+ read_from_storage(tiflash[revenue0]) */
			max(total_revenue)
		from
			revenue0
	)
order by
	s_suppkey;

drop view revenue0;
