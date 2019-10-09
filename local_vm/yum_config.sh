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
            grep -v http://mirrors.aliyuncs.com /etc/yum.repos.d/CentOS-Base_new.repo > /etc/yum.repos.d/CentOS-Base.repo && rm -rf /etc/yum.repos.d/CentOS-Base_new.repo
        elif grep -i "Red Hat" /etc/redhat-release > /dev/null ;then
            mkdir /tmp/rpm
            wget -O /tmp/rpm/yum-metadata-parser-1.1.4-10.el7.x86_64.rpm https://mirrors.aliyun.com/centos/7.7.1908/os/x86_64/Packages/yum-metadata-parser-1.1.4-10.el7.x86_64.rpm
            wget -O /tmp/rpm/yum-3.4.3-163.el7.centos.noarch.rpm https://mirrors.aliyun.com/centos/7.7.1908/os/x86_64/Packages/yum-3.4.3-163.el7.centos.noarch.rpm
            wget -O /tmp/rpm/yum-plugin-fastestmirror-1.1.31-52.el7.noarch.rpm https://mirrors.aliyun.com/centos/7.7.1908/os/x86_64/Packages/yum-plugin-fastestmirror-1.1.31-52.el7.noarch.rpm
            wget -O /tmp/rpm/yum-utils-1.1.31-52.el7.noarch.rpm https://mirrors.aliyun.com/centos/7.7.1908/os/x86_64/Packages/yum-utils-1.1.31-52.el7.noarch.rpm
            wget -O /tmp/rpm/yum-langpacks-0.4.2-7.el7.noarch.rpm https://mirrors.aliyun.com/centos/7.7.1908/os/x86_64/Packages/yum-langpacks-0.4.2-7.el7.noarch.rpm
            rpm -qa | grep yum | xargs rpm -e --nodeps
            rpm -ivh /tmp/rpm/yum-*
        else
            exit 1
        fi
    else
        echo "the is system is not centos 7|8"
        exit 1
    fi
fi
}
config_swap(){
    mem=`free -m | grep -i Mem | awk '{print $2}'`
    swap=`free -m | grep -i Swap | awk '{print $2}'`
    i=`expr $swap / $mem`
    if [ $i -eq 2 ];then
        exit 1
    elif [ $i -gt 2 ];then
        exit 1
    else
        swap_new=`expr $mem / 1024 + 1`
        dd if=/dev/zero of=/var/swapfile bs=1G count=$swap_new
        mkswap /var/swapfile
        swapon /var/swapfile
        echo "/var/swapfile swap                    swap    defaults        0 0" >> /etc/fstab
    fi
}
yum_mk_up(){
yum clean all
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
config_swap
yum_mk_up