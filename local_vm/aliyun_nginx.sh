#!/bin/sh
#安装阿里云源以及nginx
#configure /etc/apt/sources.list
sed -i 's/^deb/#deb/g' /etc/apt/sources.list
a=`cat /etc/issue | awk '{print $3}' | sed -n '1p'`
if [ $a = 9 ];then
  cat >> /etc/apt/sources.list << EOF
deb http://mirrors.aliyun.com/debian/ stretch main non-free contrib
deb-src http://mirrors.aliyun.com/debian/ stretch main non-free contrib
deb http://mirrors.aliyun.com/debian-security stretch/updates main
deb-src http://mirrors.aliyun.com/debian-security stretch/updates main
deb http://mirrors.aliyun.com/debian/ stretch-updates main non-free contrib
deb-src http://mirrors.aliyun.com/debian/ stretch-updates main non-free contrib
deb http://mirrors.aliyun.com/debian/ stretch-backports main non-free contrib
deb-src http://mirrors.aliyun.com/debian/ stretch-backports main non-free contrib
EOF

elif [ $a = 8 ];then
  cat >> /etc/apt/sources.list << EOF
deb http://mirrors.aliyun.com/debian/ jessie main non-free contrib
deb-src http://mirrors.aliyun.com/debian/ jessie main non-free contrib
deb http://mirrors.aliyun.com/debian-security jessie/updates main
deb-src http://mirrors.aliyun.com/debian-security jessie/updates main
deb http://mirrors.aliyun.com/debian/ jessie-updates main non-free contrib
deb-src http://mirrors.aliyun.com/debian/ jessie-updates main non-free contrib
deb http://mirrors.aliyun.com/debian/ jessie-backports main non-free contrib
deb-src http://mirrors.aliyun.com/debian/ jessie-backports main non-free contrib
EOF

else exit

fi

apt-get update -y

# install nginx
apt-get install wget -y
wget http://nginx.org/keys/nginx_signing.key
apt-key add nginx_signing.key
if [ $a = 9 ];then
  cat >> /etc/apt/sources.list << EOF
deb http://nginx.org/packages/mainline/debian/ stretch nginx
deb-src http://nginx.org/packages/mainline/debian/ stretch nginx
EOF

elif [ $a = 8 ];then
  cat >> /etc/apt/sources.list << EOF
deb http://nginx.org/packages/mainline/debian/ jessie nginx
deb-src http://nginx.org/packages/mainline/debian/ jessie nginx
EOF

else exit

fi
apt-get update -y && apt-get install nginx -y