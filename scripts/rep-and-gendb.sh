sed -e "s/HHUSER/$1/g"  integrated/_base/test/load_data.sh.template> integrated/_base/test/load_data.sh.t1
sed -e "s/HHPWD/$2/g" integrated/_base/test/load_data.sh.t1 > integrated/_base/test/load_data.sh
pushd ./integrated/tools && bash tpch_load.sh $3 $4 0.1 all
popd
