#!/bin/sh

# Check system
if [ ! -f /etc/lsb-release ];then
    if ! grep -Eqi "ubuntu|debian" /etc/issue;then
        echo "\033[1;31mOnly Ubuntu or Debian can run this shell.\033[0m"
        exit 1
    fi
fi

# Make sure only root can run our script
[ `whoami` != "root" ] && echo "\033[1;31mThis script must be run as root.\033[0m" && exit 1

# Version
LIBSODIUM_VER=1.0.18
MBEDTLS_VER=2.16.3
ss_file=0
v2_file=0
get_latest_ver(){
    ss_file=$(wget -qO- https://api.github.com/repos/shadowsocks/shadowsocks-libev/releases/latest | grep name | grep tar | cut -f4 -d\")
    v2_file=$(wget -qO- https://api.github.com/repos/shadowsocks/v2ray-plugin/releases/latest | grep linux-amd64 | grep name | cut -f4 -d\")
}

#nginx-install
install_nginx(){
a=`cat /etc/issue | awk '{print $3}' | sed -n '1p'`
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
    else 
      exit 
    fi
}

#v2ray-install
install_v2ray(){
    clear
	systemctl stop nginx
    apt-get install curl socat -y
    bash <(curl -L -s https://install.direct/go.sh)
    curl  https://get.acme.sh | sh
    source ~/.bashrc
    read -p "(Please enter you domain for acme):" youdomain
    ~/.acme.sh/acme.sh --issue -d $youdomain --standalone -k ec-256
    ~/.acme.sh/acme.sh --installcert -d $youdomain --fullchainpath /etc/v2ray/v2ray.crt --keypath /etc/v2ray/v2ray.key --ecc
}

#v2ray nginx configure
config_v2_nginx(){
    clear
    cat >> /etc/nginx/nginx.conf << EOF
server {
  listen  443 ssl;
  #ssl on;
  ssl_certificate       /etc/v2ray/v2ray.crt;
  ssl_certificate_key   /etc/v2ray/v2ray.key;
  ssl_protocols         TLSv1 TLSv1.1 TLSv1.2;
  ssl_ciphers           HIGH:!aNULL:!MD5;
  server_name           $youdomain;
        location /ray {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;

        # Show realip in v2ray access.log
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
		
		location /sspath {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:1000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
}
EOF
    read -p "(Please enter you UUID for v2ray):" v2uuid
    cat > /etc/v2ray/config.json << EOF
{
  "inbounds": [
    {
      "port": 10000,
      "listen":"127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$v2uuid",
            "alterId": 64
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
        "path": "/ray"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
}

# Set shadowsocks-libev config password
set_password(){
    clear
    echo "\033[1;34mPlease enter password for shadowsocks-libev:\033[0m"
    read -p "(Default password: M3chD09):" shadowsockspwd
    [ -z "${shadowsockspwd}" ] && shadowsockspwd="M3chD09"
    echo "\033[1;35mpassword = ${shadowsockspwd}\033[0m"
}

# Pre-installation
pre_install(){
    read -p "Press any key to start the installation." a
    echo "\033[1;34mStart installing. This may take a while.\033[0m"
    apt-get update
    apt-get install -y --no-install-recommends gettext build-essential autoconf libtool libpcre3-dev asciidoc xmlto libev-dev libc-ares-dev automake
}


# Installation of Libsodium
install_libsodium(){
    if [ -f /usr/lib/libsodium.a ];then
        echo "\033[1;32mLibsodium already installed, skip.\033[0m"
    else
        if [ ! -f libsodium-$LIBSODIUM_VER.tar.gz ];then
            wget https://download.libsodium.org/libsodium/releases/libsodium-$LIBSODIUM_VER.tar.gz
        fi
        tar xf libsodium-$LIBSODIUM_VER.tar.gz
        cd libsodium-$LIBSODIUM_VER
        ./configure --prefix=/usr && make
        make install
        cd ..
        ldconfig
        if [ ! -f /usr/lib/libsodium.a ];then
            echo "\033[1;31mFailed to install libsodium.\033[0m"
            exit 1
        fi
    fi
}


# Installation of MbedTLS
install_mbedtls(){
    if [ -f /usr/lib/libmbedtls.a ];then
        echo "\033[1;32mMbedTLS already installed, skip.\033[0m"
    else
        if [ ! -f mbedtls-$MBEDTLS_VER-gpl.tgz ];then
            wget https://tls.mbed.org/download/mbedtls-$MBEDTLS_VER-gpl.tgz
        fi
        tar xf mbedtls-$MBEDTLS_VER-gpl.tgz
        cd mbedtls-$MBEDTLS_VER
        make SHARED=1 CFLAGS=-fPIC
        make DESTDIR=/usr install
        cd ..
        ldconfig
        if [ ! -f /usr/lib/libmbedtls.a ];then
            echo "\033[1;31mFailed to install MbedTLS.\033[0m"
            exit 1
        fi
    fi
}


# Installation of shadowsocks-libev
install_ss(){
    if [ -f /usr/local/bin/ss-server ];then
        echo "\033[1;32mShadowsocks-libev already installed, skip.\033[0m"
    else
        if [ ! -f $ss_file ];then
            ss_url=$(wget -qO- https://api.github.com/repos/shadowsocks/shadowsocks-libev/releases/latest | grep browser_download_url | cut -f4 -d\")
            wget $ss_url
        fi
        tar xf $ss_file
        cd $(echo ${ss_file} | cut -f1-3 -d\.)
        ./configure && make
        make install
        cd ..
        if [ ! -f /usr/local/bin/ss-server ];then
            echo "\033[1;31mFailed to install shadowsocks-libev.\033[0m"
            exit 1
        fi
    fi
}


# Installation of v2ray-plugin
install_v2(){
    if [ -f /usr/local/bin/v2ray-plugin ];then
        echo "\033[1;32mv2ray-plugin already installed, skip.\033[0m"
    else
        if [ ! -f $v2_file ];then
            v2_url=$(wget -qO- https://api.github.com/repos/shadowsocks/v2ray-plugin/releases/latest | grep linux-amd64 | grep browser_download_url | cut -f4 -d\")
            wget $v2_url
        fi
        tar xf $v2_file
        mv v2ray-plugin_linux_amd64 /usr/local/bin/v2ray-plugin
        if [ ! -f /usr/local/bin/v2ray-plugin ];then
            echo "\033[1;31mFailed to install v2ray-plugin.\033[0m"
            exit 1
        fi
    fi
}

# Configure
ss_conf(){
    mkdir /etc/shadowsocks-libev
    cat >/etc/shadowsocks-libev/config.json << EOF
{
    "server":"127.0.0.1",
    "server_port":1000,
    "password":"$shadowsockspwd",
    "timeout":300,
    "method":"aes-256-gcm",
    "plugin":"v2ray-plugin",
    "plugin_opts":"server;path=/sspath;loglevel=none"
}
EOF
    cat >/lib/systemd/system/shadowsocks.service << EOF
[Unit]
Description=Shadowsocks-libev Server Service
After=network.target
[Service]
ExecStart=/usr/local/bin/ss-server -c /etc/shadowsocks-libev/config.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
}

start_nginx(){
    systemctl status nginx > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        systemctl stop nginx
    fi
    systemctl enable nginx
    systemctl start nginx
}

start_v2ray(){
    systemctl status v2ray > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        systemctl stop v2ray
    fi
    systemctl enable v2ray
    systemctl start v2ray
}

start_ss(){
    systemctl status shadowsocks > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        systemctl stop shadowsocks
    fi
    systemctl enable shadowsocks
    systemctl start shadowsocks
}

remove_files(){
    rm -f libsodium-$LIBSODIUM_VER.tar.gz mbedtls-$MBEDTLS_VER-gpl.tgz $ss_file $v2_file
    rm -rf libsodium-$LIBSODIUM_VER mbedtls-$MBEDTLS_VER $(echo ${ss_file} | cut -f1-3 -d\.)
}

print_ss_info(){
    clear
    echo "\033[1;32mCongratulations, Shadowsocks-libev server install completed\033[0m"
    echo "Your Server IP        :  ${youdomain} "
    echo "Your Server Port      :  443 "
    echo "Your Password         :  ${shadowsockspwd} "
    echo "Your Encryption Method:  aes-256-gcm "
    echo "Your Plugin           :  v2ray-plugin"
    echo "Your Plugin options   :  tls;path=/sspath"
    echo "------------------------------------------"
    echo "------------------------------------------"
    echo "------------------------------------------"
    echo "Your Server IP        :  ${youdomain} "
    echo "Your Server Port      :  443 "
    echo "Your UUID             :  $(v2uuid) "
	echo "Network Type          :  ws "
	echo "Network Path          :  /ray "
	echo "TLS                   :  enabled "
    echo "Enjoy it!"
}
install_nginx
install_v2ray
config_v2_nginx
set_password
pre_install
install_libsodium
install_mbedtls
get_latest_ver
install_ss
install_v2
ss_conf
start_nginx
start_v2ray
start_ss
remove_files
print_ss_info