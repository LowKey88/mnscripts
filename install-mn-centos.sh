#!/bin/sh
#Version 0.1.1.2a
#Info: Installs Chaincoind daemon, Masternode based on privkey, and a simple web monitor.
#Chaincoin Version 0.9.3 or above
#Tested OS: CentOS 7
#TODO: make script for CentOS's Geek
#TODO: remove dependency on sudo user account to run script (i.e. run as root and specifiy chaincoin user so chaincoin user does not require sudo privileges)
#TODO: add specific dependencies depending on build option (i.e. gui requires QT4)
# hisyamnasir[at]gmail.com - HisyamNasir / LowKey

noflags() {
        echo "┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄"
    echo "Usage: install-mn [options]"
    echo "Valid options are:"
    echo "MASTERNODE_PRIVKEY(Required)"
    echo "Example: install-mn 6F9E1DCDNFcr3hr5tWVcNSR4VniWNZ1SNxX4k83keHUGy52RQda"
    echo "┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄"
    exit 1
}

message() {
        echo "╒════════════════════════════════════════════════════════════════════════════════>>"
        echo "| $1"
        echo "╘════════════════════════════════════════════<<<"
}

error() {
        message "An error occured, you must fix it to continue!"
        exit 1
}

success() {
        chaincoind
        message "SUCCESS! Your chaincoind has started."
        exit 0
}

prepdependencies() { #TODO: Install tools & dependencies
        message "Installing dependencies..."
        yum update -y
        yum groupinstall "Development Tools" -y
        yum install wget screen nano net-tools -y
        yum install epel-release.noarch -y
        yum update -y
        yum install autoconf automake boost-devel gcc-c++ libtool libdb4-cxx libdb4-cxx-devel miniupnpc-devel openssl-devel libevent-devel git zlib-devel bzip2-devel python-devel -y
}

miniupnpc() { #TODO: install miniupnp client
        message "Installing miniupnpc..."
        cd ~/
        mkdir miniupnpc
        cd miniupnpc
        wget http://miniupnp.free.fr/files/download.php?file=miniupnpc-1.9.tar.gz
        mv download.php\?file\=miniupnpc-1.9.tar.gz miniupnpc-1.9.tar.gz
        tar zxvf miniupnpc-1.9.tar.gz
        cd miniupnpc-1.9
        make && make install -y
        cd ~/
        rm -rf miniupnpc
}

settime() {
        message "Changing Timezone.."        
        rm /etc/localtime
        ln -s /usr/share/zoneinfo/Asia/Kuala_Lumpur /etc/localtime
        message "Installing ntp.."
        yum install ntp ntpdate ntp-doc -y
        chkconfig ntpd on
        ntpdate pool.ntp.org
        service ntpd restart
}

createswap() { #TODO: add error detection
        message "Creating 2GB temporary swap file...this may take a few minutes..."
        sudo dd if=/dev/zero of=/swapfile bs=1M count=2000
        sudo mkswap /swapfile
        sudo chown root:root /swapfile
        sudo chmod 0600 /swapfile
        sudo swapon /swapfile
}

clonerepo() { #TODO: add error detection
        message "Cloning from github repository..."
        cd ~/
        git clone https://github.com/chaincoin/chaincoin.git
}

compile() {
        cd chaincoin #TODO: squash relative path
        message "Preparing to build..."
        ./autogen.sh
        if [ $? -ne 0 ]; then error; fi
        message "Configuring build options..."
        ./configure $1 --disable-tests
        if [ $? -ne 0 ]; then error; fi
        message "Building ChainCoin...this may take a few minutes..."
        make
        if [ $? -ne 0 ]; then error; fi
        message "Installing ChainCoin..."
        sudo make install
        if [ $? -ne 0 ]; then error; fi
}

createconf() {
        #TODO: Can check for flag and skip this
        #TODO: Random generate the user and password

        message "Creating chaincoin.conf..."

        CONFDIR=~/.chaincoin
        if [ ! -d "$CONFDIR" ]; then mkdir $CONFDIR; fi
        if [ $? -ne 0 ]; then error; fi

        mnip=$(curl -s https://api.ipify.org)
        rpcuser=$(date +%s | sha256sum | base64 | head -c 10 ; echo)
        rpcpass=$(openssl rand -base64 32)
        printf "%s\n" "rpcuser=$rpcuser" "rpcpassword=$rpcpass" "rpcallowip=127.0.0.1" "listen=1" "server=1" "daemon=1" "maxconnections=256" "rpcport=11995" "externalip=$mnip" "bind=$mnip" "masternode=1" "masternodeprivkey=$MNPRIVKEY" "masternodeaddr=$mnip:11994" > $CONFDIR/chaincoin.conf

}

createhttp() {
        cd ~/
        mkdir web
        cd web
        wget https://raw.githubusercontent.com/chaoabunga/chc-scripts/master/index.html
        wget https://raw.githubusercontent.com/chaoabunga/chc-scripts/master/stats.txt
        (crontab -l 2>/dev/null; echo "* * * * * echo MN Count:  > ~/web/stats.txt; /usr/local/bin/chaincoind masternode count >> ~/web/stats.txt; /usr/local/bin/chaincoind getinfo >> ~/web/stats.txt") | crontab -
        mnip=$(curl -s https://api.ipify.org)
        sudo python3 -m http.server 8000 --bind $mnip 2>/dev/null &
        echo "Web Server Started!  You can now access your stats page at http://$mnip:8000"
}

install() {
        prepdependencies
        miniupnpc
        settime
        #createswap
        clonerepo
        compile $1
        createconf
        createhttp
        success
}

#main
#default to --without-gui
if [ -z $1 ]
then
        noflags
fi
MNPRIVKEY=$1
install --without-gui
