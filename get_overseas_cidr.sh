#!/bin/bash

data_date=$(TZ=UTC+24 date +%Y%m%d)


## 获取境外CIDR
wget -O- "https://ftp.apnic.net/stats/apnic/$(TZ=UTC date +%Y)/delegated-apnic-${data_date}.gz" | \
    gzip -d | grep -v ipv6 | grep -v asn | grep -v "|CN|" | grep -v summary | \
    awk -F\| '!/^\s*(#.*)?$/&&/\|ipv4/{print $4 "/" 32-log($5)/log(2)}' > overseas_cidr-${data_date}.txt


## 生成爱快IP分组导入文件
rm -f overseas_ikuai_ipgroup-${data_date}.txt
num_cidr=1
num_line=1
num_id=50
comment=
addr_pool=
while read cidr
do
    if [[ $num_cidr == 1 ]];then
        comment=
        addr_pool=${cidr}
    else
        comment=${comment},
        addr_pool=${addr_pool},${cidr}
    fi
    if [[ $num_cidr -lt 1000 ]];then
        let num_cidr=${num_cidr}+1
    else
        echo "id=${num_id} comment=${comment} type=0 group_name=境外IP-${data_date}-${num_line} addr_pool=${addr_pool}" >> overseas_ikuai_ipgroup-${data_date}.txt
        let num_id=${num_id}+1
        comment=
        let num_line=${num_line}+1
        addr_pool=
        num_cidr=1
    fi
done < overseas_cidr-${data_date}.txt
if [[ $num_cidr -gt 1 ]];then
    echo "id=${num_id} comment=${comment} type=0 group_name=境外IP-${data_date}-${num_line} addr_pool=${addr_pool}" >> overseas_ikuai_ipgroup-${data_date}.txt
fi
rm -f overseas_cidr-${data_date}.txt


## 生成爱快ACL规则导入文件
rm -f overseas_ikuai_acl-${data_date}.txt
src_addr=
i=1
while [[ $i -le ${num_line} ]]
do
    if [[ $i == 1 ]];then
        src_addr=境外IP-${data_date}-${i}
    else
        src_addr=${src_addr},境外IP-${data_date}-${i}
    fi
    let i=${i}+1
done
echo "id=50 enabled=yes comment=屏蔽境外IP访问 action=drop dir=forward ctdir=1 iinterface=any ointerface=any src_addr=${src_addr} dst_addr= src6_addr= dst6_addr= src6_mode=0 dst6_mode=0 src6_suffix= dst6_suffix= src6_mac= dst6_mac= protocol=any src_port= dst_port= week=1234567 time=00:00-23:59 ip_type=4" > overseas_ikuai_acl-${data_date}.txt