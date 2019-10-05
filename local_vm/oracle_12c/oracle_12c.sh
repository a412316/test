#!/bin/bash
config_hosts(){
    hostname=`(hostname)`
    hostname1=`hostname | awk -F "." '{print $1}'`
    ip=`ip a | grep inet | grep eth0 | awk '{print $2}' | awk -F "/" '{print $1}'`
    echo "$ip   $hostname1 $hostname" >> /etc/hosts
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

config_environment(){
    #Install oracle dependency
    yum install -y  binutils  compat-libcap1  compat-libstdc++-33  compat-libstdc++-33.i686  glibc  glibc.i686 glibc-devel glibc-devel.i686 ksh  libaio  libaio.i686  libaio-devel  libaio-devel.i686  libX11  libX11.i686  libXau  libXau.i686 libXi  libXi.i686  libXtst  libXtst.i686  libgcc  libgcc.i686  libstdc++  libstdc++.i686  libstdc++-devel  libstdc++-devel.i686  libxcb  libxcb.i686  make  nfs-utils  net-tools  smartmontools  sysstat  unixODBC  unixODBC-devel    gcc   gcc-c++   libXext   libXext.i686   zlib-devel   zlib-devel.i686
    
    #Configuring kernel parameters
    shmmax=$((($mem/1024+1)*1024*1024*1024-1))
    shmall=$((($mem/1024+1)*1024*1024/4))
    cat >> /etc/sysctl.conf << EOF
fs.file-max = 6815744
kernel.sem = 250 32000 100 128
kernel.shmmni = 4096
kernel.shmall = $shmall
kernel.shmmax = $shmmax
kernel.panic_on_oops = 1
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
fs.aio-max-nr = 1048576
net.ipv4.ip_local_port_range = 9000 65500
EOF
    sysctl -p
    
    #Configuring oracle resource limits
    cat >> /etc/security/limits.conf << EOF
oracle soft nproc 2047
oracle hard nproc 16384
oracle soft nofile 1024
oracle hard nofile 65536
oracle soft stack 10240
EOF

    #Create users and groups
    groupadd oinstall
    groupadd dba
    groupadd oper
    useradd -g oinstall -G dba,oper oracle
    echo oracle | passwd --stdin oracle
    
    #Create a database directory and extract the installation package 
    mkdir -p /u01/app/oracle/oradata
    mkdir -p /u01/app/oracle/oradata_back
    zip=`ls /tmp | grep zip`
    unzip -d /u01/app/oracle/ /tmp/$zip
    rm -rf /tmp/$zip
    chmod -R 755 /u01
    chown -R oracle:oinstall /u01
    
    #Configuring environment variables
    cat >> /home/oracle/.bash_profile << EOF
# Oracle Settings 
export TMP=/tmp
export TMPDIR=\$TMP
 
export ORACLE_HOSTNAME=$hostname
export ORACLE_UNQNAME=hisdb
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=\$ORACLE_BASE/product/12.2.0.1/db_1
export ORACLE_SID=hisdb
 
export PATH=/usr/sbin:\$PATH
export PATH=\$ORACLE_HOME/bin:\$PATH
 
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=\$ORACLE_HOME/jlib:\$ORACLE_HOME/rdbms/jlib  
export PATH=/usr/sbin:\$PATH  
export PATH=\$ORACLE_HOME/bin:\$PATH  
  
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:/lib:/usr/lib  
export CLASSPATH=\$ORACLE_HOME/jlib:\$ORACLE_HOME/rdbms/jlib
EOF
}

#start install oracle software and start listen
install_database_software(){
oracle_out='/tmp/oracle.out'
wget -O /tmp/install_db.rsp 
wget -O /tmp/netca.rsp
su oracle -lc "/u01/app/oracle/database/runInstaller -force -silent -noconfig -responseFile /tmp/install_db.rsp" 1> ${oracle_out}
echo -e "\033[34mInstallNotice >>\033[0m \033[32moracle install starting \033[05m...\033[0m"
while true; do
    grep '[FATAL] [INS-10101]' ${oracle_out} &> /dev/null
    if [[ $? == 0 ]];then
        echo -e "\033[34mInstallNotice >>\033[0m \033[31moracle start install has [ERROR]\033[0m"
        cat ${oracle_out}
        exit
    fi
    cat /tmp/oracle.out  | grep sh
    if [[ $? == 0 ]];then
        `cat /tmp/oracle.out  | grep sh | awk -F ' ' '{print $2}' | head -1`
        if [[ $? == 0 ]]; then
            echo -e "\033[34mInstallNotice >>\033[0m \033[32mScript 1 run ok\033[0m"
        else
            echo -e "\033[34mInstallNotice >>\033[0m \033[31mScript 1 run faild\033[0m"
        fi
        `cat /tmp/oracle.out  | grep sh | awk -F ' ' '{print $2}' | tail -1`
        if [[ $? == 0 ]]; then
            echo -e "\033[34mInstallNotice >>\033[0m \033[32mScript 1 run ok\033[0m"
        else
            echo -e "\033[34mInstallNotice >>\033[0m \033[31mScript 1 run faild\033[0m"
        fi
        su oracle -lc "netca -silent -responsefile /tmp/netca.rsp"
        netstat -anptu | grep 1521
        if [[ $? == 0 ]]; then
            echo -e "\033[34mInstallNotice >>\033[0m \033[32mOracle run listen\033[0m"
            break
        else
            echo -e "\033[34mInstallNotice >>\033[0m \033[31mOracle no run listen\033[0m"
            exit
        fi
    fi
done
}

Create_database(){
wget -O /tmp/dbca.rsp
install_out='/tmp/install.out'
su oracle -lc "dbca -silent -createDatabase  -responseFile /tmp/dbca.rsp" 1> ${install_out}
while true; do
    cat /tmp/install.out | grep '100%' > /dev/null
    if [[ $? == 0 ]];then
        echo ok
        exit
    else
        echo -e "\033[34mInstallNotice >>\033[0m \033[32mDatabase is create\033[0m" 
    fi
done
}

oracle_boot(){
    sed -i 's/N/Y/g' /etc/oratab
    sed -i 's/ORACLE_HOME_LISTNER=$1/ORACLE_HOME_LISTNER=$ORACLE_HOME/g' /u01/app/oracle/product/12.2.0.1/db_1/bin/dbstart
    cat >> /etc/rc.d/rc.local << EOF
su oracle -lc "/u01/app/oracle/product/12.2.0.1/db_1/bin/lsnrctl start"
su oracle -lc /u01/app/oracle/product/12.2.0.1/db_1/bin/dbstart
EOF
    chmod +x /etc/rc.d/rc.local
}

config_hosts
config_swap
config_environment
Create_database
oracle_boot