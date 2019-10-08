#!/bin/bash
yum_config(){
if [ ! -f /etc/redhat-release ];then
    exit 1
else
    rm -rf /etc/yum.repos.d/*.repo
    release=`cat /etc/redhat-release | awk -F "." '{print $1}' | tr -cd 0-9`
    if [ $release = 8 ];then
        cat > /etc/yum.repos.d/AppStream.repo << EOF
[AppStream]
name = AppStream
baseurl = https://mirrors.aliyun.com/centos/8.0.1905/AppStream/x86_64/os/
gpgcheck = 0
enabled = 1
EOF
            cat > /etc/yum.repos.d/BaseOS.repo << EOF
[BaseOS]
name = BaseOS
baseurl = https://mirrors.aliyun.com/centos/8.0.1905/BaseOS/x86_64/os/
gpgcheck= 0
enabled= 1
EOF
            cat > /etc/yum.repos.d/extras.repo << EOF
[extras]
name = extras
baseurl = https://mirrors.aliyun.com/centos/8.0.1905/extras/x86_64/os/
gpgcheck = 0
enabled = 1
EOF
    elif [ $release = 7 ];then
        if grep -i CentOS /etc/redhat-release > /dev/null ;then
            wget -O /etc/yum.repos.d/CentOS-Base_new.repo http://mirrors.aliyun.com/repo/Centos-7.repo
            sed -i 's/$releasever/7.7.1908/g' /etc/yum.repos.d/CentOS-Base_new.repo
            sed -i 's/$basearch/x86_64/g' /etc/yum.repos.d/CentOS-Base_new.repo
            gerp -v http://mirrors.aliyuncs.com /etc/yum.repos.d/CentOS-Base_new.repo > /etc/yum.repos.d/CentOS-Base.repo && rm -rf /etc/yum.repos.d/CentOS-Base_new.repo
        elif grep -i "Red Hat" /etc/redhat-release > /dev/null ;then
            rpm -qa | grep yum 
        else
            exit 1
        fi
    else
        echo "the is system is not centos 7|8"
        exit 1
    fi
fi
}
yum_mk_up(){
yum makecache
if [ $release = 8 ];then
    if grep -i "Red Hat" /etc/redhat-release > /dev/null ;then
        yum update -y -x 'google-noto-serif-cjk-ttc-fonts'
    else
        yum update -y
    fi
elif [ $release = 7 ];then
    if grep -i "Red Hat" /etc/redhat-release > /dev/null ;then
        yum update -y
        cp -r /boot/grub2/ /boot/efi/EFI/centos
    else
        yum install epel-release -y
        yum makecache
        yum update -y
    fi
else
    exit 1
fi
read -s -n1 -p "Press any key to reboot"
reboot
}
yum_config
yum_mk_up