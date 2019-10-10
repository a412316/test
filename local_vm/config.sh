#!/bin/bash

#Set the host name
config_hostname(){
    read -p "Please enter a new hostname:" namehost
    hostnamectl set-hostname $namehost
}

#config firewalld and selinux
config_firewalld_selinux(){
    systemctl stop firewalld
    systemctl disable firewalld
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
}

#Collect machine current IP information
collect_ip(){
    network_card=`nmcli connection show | grep -v virbr0 | grep -v NAME | awk '{print $1}'`
    ipaddress=`ip a | grep inet | grep -v 127.0.0.1 | grep virbr0 -v | grep -v inet6 | awk '{print $2}' | awk -F "/" '{print $1}'`
    netmask=`ip a | grep inet | grep -v 127.0.0.1 | grep virbr0 -v | grep -v inet6 | awk '{print $2}' | awk -F "/" '{print $2}'`
    gateway=`netstat -rn | sed -n '3p' | awk '{print $2}'`
    echo "network_card=$network_card" >> /tmp/onfig.out
    echo "ipaddress=$ipaddress" >> /tmp/onfig.out
    echo "netmask=$network_card" >> /tmp/onfig.out
    echo "gateway=$gateway" >> /tmp/onfig.out
}

#Configure the NIC as eth0
config_nic_eth0(){
    if [ ! -f /etc/redhat-release ];then
        echo "This system is not centos or redhat" >> /tmp/config.out
        exit 1
    else
        release=`cat /etc/redhat-release | awk -F "." '{print $1}' | tr -cd 0-9`
        if [ $release -ge 7 ];then
            grep net.ifnames=0 /etc/default/grub > /dev/null
            if [ $? == 0 ];then
                echo "NIC is eth0" >> /tmp/config.out
            else
                rows=`cat /etc/default/grub -n | grep /root | awk '{print $1}'`
                if grep -i centos /etc/default/grub >> /dev/null ;then
                    sed -i ''$rows'c GRUB_CMDLINE_LINUX="rd.lvm.lv=centos/root rd.lvm.lv=centos/swap net.ifnames=0 biosdevname=0 rhgb quiet"' /etc/default/grub
                elif grep -i rhel /etc/default/grub >> /dev/null ;then
                    sed -i ''$rows'c GRUB_CMDLINE_LINUX="rd.lvm.lv=rhel/root rd.lvm.lv=rhel/swap net.ifnames=0 biosdevname=0 rhgb quiet"' /etc/default/grub
                fi
                grub2-mkconfig -o /boot/grub2/grub.cfg
                nmcli connection delete "$network_card"
            fi
        else
            echo "Centos id not more than the 7"
            exit 1
        fi
    fi
}

#new sh
new_sh(){
    cat >> /tmp/config2.sh <<-BBB
#!/bin/bash

#config ip
config_ip(){
    ip a | grep eth0 >> /dev/null
    if [ \$? == 0 ];then
        nmcli connection show | grep -i wired >> /dev/null
        if [ \$? == 0 ];then
            name1=\`nmcli connection show | grep eth0 | awk '{print \$1}'\`
            name2=\`nmcli connection show | grep eth0 | awk '{print \$2}'\`
            name3=\`nmcli connection show | grep eth0 | awk '{print \$3}'\`
            name4="\$name1 \$name2 \$name3"
            nmcli connection delete "\$name4"
        else
            ll /etc/sysconfig/network-scripts/ifcfg-eth0 && grep dhcp /etc/sysconfig/network-scripts/ifcfg-eth0 > /dev/null
            if [ \$? == 0 ];then
                nmcli connection delete eth0
            else
                echo "eth0 is static" >> /tmp/config.out
            fi
        fi
    else
        echo "NIC is not eth0" >> /tmp/config.out
    fi
    nmcli connection add con-name eth0 ifname eth0 type ethernet autoconnect yes ip4 $ipaddress/$netmask gw4 $gateway
    cat >> /etc/sysconfig/network-scripts/ifcfg-eth0 << EOF
DNS1=223.5.5.5
DNS2=$gateway
EOF
    systemctl restart NetworkManager
    nmcli connection down eth0 ; nmcli connection up eth0
    sleep 5
}

#config /etc/hosts
config_hosts(){
    ping -c 5 baidu.com >> /tmp/config.out
    grep not /tmp/config.out
    if [ \$? == 0 ];then
        echo "Please check the network configuration" >> /tmp/config.out
        cat /tmp/config.out
    else
        ipaddress=\`ip a | grep inet | grep -v 127.0.0.1 | grep virbr0 -v | grep -v inet6 | awk '{print \$2}' | awk -F "/" '{print \$1}'\`
        hostname | grep . >> /dev/null
        if [ \$? == 0 ];then
            hostname1=\`hostname | awk -F "." '{print \$1}'\`
            hostname2=\$(hostname)
            echo "\$ipaddress   \$hostname1 \$hostname2" >> /etc/hosts
        else
            hostname2=\$(hostname)
            echo "\$ipaddress   \$hostname2" >> /etc/hosts
        fi
    fi
}

#config yum
yum_config(){
if [ ! -f /etc/redhat-release ];then
    exit 1
else
    rm -rf /etc/yum.repos.d/*.repo
    release=\`cat /etc/redhat-release | awk -F "." '{print \$1}' | tr -cd 0-9\`
    if [ \$release = 8 ];then
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
    elif [ \$release = 7 ];then
        if grep -i "Red Hat" /etc/redhat-release > /dev/null ;then
            mkdir -p /tmp/rpm
            wget -O /tmp/rpm/yum-metadata-parser-1.1.4-10.el7.x86_64.rpm https://mirrors.aliyun.com/centos/7.7.1908/os/x86_64/Packages/yum-metadata-parser-1.1.4-10.el7.x86_64.rpm
            wget -O /tmp/rpm/yum-3.4.3-163.el7.centos.noarch.rpm https://mirrors.aliyun.com/centos/7.7.1908/os/x86_64/Packages/yum-3.4.3-163.el7.centos.noarch.rpm
            wget -O /tmp/rpm/yum-plugin-fastestmirror-1.1.31-52.el7.noarch.rpm https://mirrors.aliyun.com/centos/7.7.1908/os/x86_64/Packages/yum-plugin-fastestmirror-1.1.31-52.el7.noarch.rpm
            wget -O /tmp/rpm/yum-utils-1.1.31-52.el7.noarch.rpm https://mirrors.aliyun.com/centos/7.7.1908/os/x86_64/Packages/yum-utils-1.1.31-52.el7.noarch.rpm
            wget -O /tmp/rpm/yum-langpacks-0.4.2-7.el7.noarch.rpm https://mirrors.aliyun.com/centos/7.7.1908/os/x86_64/Packages/yum-langpacks-0.4.2-7.el7.noarch.rpm
            rpm -qa | grep yum | xargs rpm -e --nodeps
            sleep 2
            rpm -ivh /tmp/rpm/yum-* && rm -rf /tmp/rpm && yum clean all
            sleep 5
            ll /etc/yum.repos.d/redhat.repo && rm -rf /etc/yum.repos.d/redhat.repo
        fi
        sleep 5
        ll /etc/yum.repos.d/redhat.repo && rm -rf /etc/yum.repos.d/redhat.repo
        wget -O /etc/yum.repos.d/CentOS-Base_new.repo http://mirrors.aliyun.com/repo/Centos-7.repo
        sed -i 's/\$releasever/7.7.1908/g' /etc/yum.repos.d/CentOS-Base_new.repo
        sed -i 's/\$basearch/x86_64/g' /etc/yum.repos.d/CentOS-Base_new.repo
        grep -v http://mirrors.aliyuncs.com /etc/yum.repos.d/CentOS-Base_new.repo | grep -v http://mirrors.cloud.aliyuncs.com > /etc/yum.repos.d/CentOS-Base.repo && rm -rf /etc/yum.repos.d/CentOS-Base_new.repo
    else
        echo "the is system is not centos 7|8"
        exit 1
    fi
fi
}

#config swap
config_swap(){
    mem=\`free -m | grep -i Mem | awk '{print \$2}'\`
    swap=\`free -m | grep -i Swap | awk '{print \$2}'\`
    i=\`expr \$swap / \$mem\`
    if [ \$i -ge 2 ];then
        exit 1
    else
        swap_new=\$(((\$mem * 2 - \$swap) / 1024 + 1))
        dd if=/dev/zero of=/var/swapfile bs=1G count=\$swap_new
        mkswap /var/swapfile
        swapon /var/swapfile
        echo "/var/swapfile swap                    swap    defaults        0 0" >> /etc/fstab
    fi
}

#yum update and makechche
yum_mk_up(){
yum makecache
yum install epel-release -y
if [ \$release = 8 ];then
    if grep -i "Red Hat" /etc/redhat-release > /dev/null ;then
        yum update -y -x 'google-noto-serif-cjk-ttc-fonts'
    else
        yum update -y
    fi
elif [ \$release = 7 ];then
    if grep -i "Red Hat" /etc/redhat-release > /dev/null ;then
        yum update -y || yum update -y
        cp /boot/grub2/grub.cfg /boot/efi/EFI/centos
    else
        yum makecache
        yum update -y
    fi
else
    exit 1
fi
}

#clean
clean_file(){
    line=\`cat -n /etc/rc.d/rc.local | grep config2.sh | awk '{print \$1}'\`
    sed -i ""\$line"d" /etc/rc.d/rc.local
    rm -rf /tmp/config1.sh
    rm -rf /tmp/config2.sh
    reboot
}

config_ip
config_hosts
yum_config
config_swap
yum_mk_up
clean_file    
BBB
}

#Script gives permission and reboot
sgp_re(){
    chmod +x /tmp/config2.sh
    chmod +x /etc/rc.d/rc.local
    echo "bash /tmp/config2.sh | tee /tmp/config2.out" >> /etc/rc.d/rc.local
    reboot
}

config_hostname
config_firewalld_selinux
collect_ip
config_nic_eth0
new_sh
sgp_re