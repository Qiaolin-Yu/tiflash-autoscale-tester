function _fio_test()
{
	local rw="${1}"
	local bs="${2}"
	local sec="${3}"
	local jobn="${4}"
	local file="${5}"
	local log="${6}"
	local size="${7}"
	local aio="${8}"

	if [ "${aio}" != 'true' ]; then
		local cmd="fio -numjobs=${jobn}"
	else
		local cmd="fio -numjobs=1 ioengine=libaio iodepth=${jobn}"
	fi

	#echo ${cmd} -filename="${file}" -direct=1 -rw="${rw}" -size "${size}" -bs="${bs}" -runtime="${sec}" -group_reporting -name=pc >&2

	${cmd} -filename="${file}" -direct=1 -rw="${rw}" -size "${size}" \
		-bs="${bs}" -runtime="${sec}" -group_reporting -name=pc | \
		tee -a ${log} | { grep IOPS || test $? == 1; } | awk -F ': ' '{print $2}'
}
export -f _fio_test

function _fio_standard()
{
	local threads="$1"
	local file="${2}"
	local log="${3}"
	local sec="${4}"
	local size="${5}"
	local aio="${6}"

	local wl_w=`_fio_test 'write' 64k "${sec}" "${threads}" "${file}" "${log}" "${size}" "${aio}"`
	local wl_r=`_fio_test 'read'  64k "${sec}" "${threads}" "${file}" "${log}" "${size}" "${aio}"`
	local wl_iops_w=`echo "${wl_w}" | awk -F ',' '{print $1}'`
	local wl_iops_r=`echo "${wl_r}" | awk -F ',' '{print $1}'`
	local wl_iotp_w=`echo "${wl_w}" | awk '{print $2}'`
	local wl_iotp_r=`echo "${wl_r}" | awk '{print $2}'`
	echo "64K, ${threads} threads: Write: ${wl_iops_w} ${wl_iotp_w}, Read: ${wl_iops_r} ${wl_iotp_r}"
}
export -f _fio_standard

function fio_report()
{
	if [ -z "${6+x}" ]; then
		echo "[func fio_report] usage: <func> test_file test_log each_test_sec test_file_size threads use_aio" >&2
		return 1
	fi

	local file="${1}"
	local log="${2}"
	local sec="${3}"
	local size="${4}"
	local threads="${5}"
	local aio="${6}"

	local iops_w=`_fio_test randwrite 4k "${sec}" "${threads}" "${file}" "${log}" "${size}" "${aio}" | awk -F ',' '{print $1}'`
	local iops_r=`_fio_test randread  4k "${sec}" "${threads}" "${file}" "${log}" "${size}" "${aio}" | awk -F ',' '{print $1}'`
	local iotp_w=`_fio_test randwrite 4m "${sec}" "${threads}" "${file}" "${log}" "${size}" "${aio}" | awk '{print $2}'`
	local iotp_r=`_fio_test randread  4m "${sec}" "${threads}" "${file}" "${log}" "${size}" "${aio}" | awk '{print $2}'`

	echo "Max: RandWrite: (4K)${iops_w} (4M)${iotp_w}, RandRead: (4K)${iops_r} (4M)${iotp_r}"

	_fio_standard "4" "${file}" "${log}" "${sec}" "${size}" "${aio}"
	_fio_standard "8" "${file}" "${log}" "${sec}" "${size}" "${aio}"
	_fio_standard "16" "${file}" "${log}" "${sec}" "${size}" "${aio}"
	_fio_standard "32" "${file}" "${log}" "${sec}" "${size}" "${aio}"

	rm -f "$log.w.stable"
	for ((i = 0; i < 5; i++)); do
		_fio_test randwrite 64k "${sec}" "${threads}" "${file}" "${log}" "${size}" "${aio}" >> "$log.w.stable"
	done
	local w_stable=(`cat "$log.w.stable" | awk -F 'BW=' '{print $2}' | awk '{print $1}'`)
	echo "RandWrite stable test: (64K 8t) ["${w_stable[@]}"]"

	rm -f "$log.r.stable"
	for ((i = 0; i < 5; i++)); do
		_fio_test randread 64k "${sec}" "${threads}" "${file}" "${log}" "${size}" "${aio}" >> "$log.r.stable"
	done
	local r_stable=(`cat "$log.r.stable" | awk -F 'BW=' '{print $2}' | awk '{print $1}'`)
	echo "RandRead stable test: (64K 8t) ["${r_stable[@]}"]"
}
export -f fio_report
