-- using 1365545250 as a seed to the RNG


select /**/
	cntrycode,
	count(*) as numcust,
	sum(c_acctbal) as totacctbal
from
	(
		select /*+ read_from_storage(tiflash[customer]) */
			substring(c_phone from 1 for 2) as cntrycode,
			c_acctbal
		from
			customer
		where
			substring(c_phone from 1 for 2) in
				('20', '40', '22', '30', '39', '42', '21')
			and c_acctbal > (
				select /*+ read_from_storage(tiflash[customer]) */
					avg(c_acctbal)
				from
					customer
				where
					c_acctbal > 0.00
					and substring(c_phone from 1 for 2) in
						('20', '40', '22', '30', '39', '42', '21')
			)
			and not exists (
				select /*+ read_from_storage(tiflash[orders]) */
					*
				from
					orders
				where
					o_custkey = c_custkey
			)
	) as custsale
group by
	cntrycode
order by
	cntrycode;
