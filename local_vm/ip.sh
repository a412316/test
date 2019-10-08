#!/bin/bash
if [ ! -f /etc/redhat-release ];then
    exit 1
else
    release=`cat /etc/redhat-release | awk -F "." '{print $1}' | tr -cd 0-9`
    if [ $release -ge 7 ];then
        read -p "input new hostname:" namehost
        hostnamectl set-hostname $namehost
        systemctl stop firewalld
        systemctl disable firewalld
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        network_card=`nmcli connection show | grep -v virbr0 | grep -v NAME | awk '{print $1}'`
        ipaddress=`ip a | grep inet | grep -v 127.0.0.1 | grep virbr0 -v | grep -v inet6 | awk '{print $2}' | awk -F "/" '{print $1}'`
        netmask=`ip a | grep inet | grep -v 127.0.0.1 | grep virbr0 -v | grep -v inet6 | awk '{print $2}' | awk -F "/" '{print $2}'`
        gateway=`netstat -rn | sed -n '3p' | awk '{print $2}'`
        echo "network_card=$network_card" > /tmp/1.txt
        echo "ipaddress=$ipaddress" >> /tmp/1.txt
        echo "netmask=$network_card" >> /tmp/1.txt
        echo "gateway=$gateway" >> /tmp/1.txt
        grep net.ifnames=0 /etc/default/grub > /dev/null
        if [ $? == 0 ];then 
            echo "Network Card is eth0"
            grep dhcp /etc/sysconfig/network-scripts/ifcfg-eth0 > /dev/null
            if [ $? == 0 ];then
                nmcli connection delete eth0
                nmcli connection add con-name eth0 ifname eth0 type ethernet autoconnect yes ip4 $ipaddress/24 gw4 $gateway
                cat >> /etc/sysconfig/network-scripts/ifcfg-eth0 << EOF
DNS1=223.5.5.5
DNS2=$gateway
EOF
            else
                echo "Network is ststic"
                exit 1
            fi
        else
            rows=`cat /etc/default/grub -n | grep /root | awk '{print $1}'`
            sed -i ''$rows'c GRUB_CMDLINE_LINUX="rd.lvm.lv=centos/root rd.lvm.lv=centos/swap net.ifnames=0 biosdevname=0 rhgb quiet"' /etc/default/grub
            grub2-mkconfig -o /boot/grub2/grub.cfg
            nmcli connection delete "$network_card"
            cat > /tmp/ip2.sh << EOF
#!/bin/bash
ip a | grep eth0 > /dev/null
if [ \$? == 0 ];then
    nmcli connection show | grep -i wired >> /dev/null
    if [ \$? == 0 ];then
        name1=\`nmcli connection show | grep eth0 | awk '{print \$1}'\`
        name2=\`nmcli connection show | grep eth0 | awk '{print \$2}'\`
        name3=\`nmcli connection show | grep eth0 | awk '{print \$3}'\`
        name4="\$name1 \$name2 \$name3"
        nmcli connection delete "\$name4"
        nmcli connection show | grep -i wired >> /dev/null
        if [ \$? == 0 ];then
            exit
        else
            nmcli connection add con-name eth0 ifname eth0 type ethernet autoconnect yes ip4 $ipaddress/$netmask gw4 $gateway
        fi
    else
        nmcli connection show | awk '{print \$1}' | grep eth0 >> /dev/null
        if [ \$? == 0 ];then
            nmcli connection delete eth0
            nmcli connection add con-name eth0 ifname eth0 type ethernet autoconnect yes ip4 $ipaddress/$netmask gw4 $gateway
        else
            nmcli connection add con-name eth0 ifname eth0 type ethernet autoconnect yes ip4 $ipaddress/$netmask gw4 $gateway
        fi
    fi
    echo "DNS1=223.5.5.5" >> /etc/sysconfig/network-scripts/ifcfg-eth0
    echo "DNS2=$gateway" >> /etc/sysconfig/network-scripts/ifcfg-eth0
    systemctl restart NetworkManager
    nmcli connection down eth0 ; nmcli connection up eth0
    sleep 5
    ping -c 5 baidu.com >> /tmp/1.txt
    grep not /tmp/1.txt
    if [ \$? == 0 ];then
        echo "Please check the network configuration" >> /tmp/1.txt
        cat /tmp/1.txt
    else
        ipaddress=\`ip a | grep inet | grep -v 127.0.0.1 | grep virbr0 -v | grep -v inet6 | awk '{print \$2}' | awk -F "/" '{print \$1}'\`
        hostname | grep . >> /dev/null
        if [ \$? == 0 ];then
            hostname1=\`hostname | awk -F "." '{print $1}'\`
            hostname2=\$(hostname)
            echo "\$ipaddress   \$hostname1 \$hostname2" >> /etc/hosts
        else
            hostname2=\$(hostname)
            echo "\$ipaddress   \$hostname2" >> /etc/hosts
        fi
        wget -O /tmp/yum_config.sh https://raw.githubusercontent.com/a412316/test/master/local_vm/yum_config.sh && chmod +x /tmp/yum_config.sh && bash /tmp/yum_config.sh | tee /tmp/yumconfg.log
    fi
else
    echo "Network Card is not eth0"
    exit 1
fi
EOF
            chmod +x /tmp/ip2.sh
            chmod +x /etc/rc.d/rc.local
            echo "/tmp/ip2.sh" >> /etc/rc.d/rc.local
            reboot
		fi
	else
        echo "Centos id not more than the 7"
		exit 1
    fi
fi