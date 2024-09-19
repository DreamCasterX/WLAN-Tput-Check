#!/usr/bin/env bash

# CREATOR: mike.lu@hp.com
# CHANGE DATE: 2024/09/19
__version__="1.1"


# Define partner client info
HOST_NAME="u"
PASSWORD="u"


# RHEL 9 packages 
iperf_9="iperf3-3.9-11.el9.x86_64.rpm"                     # 3.9-10 (RHEL 9.4 GA)
lksctp_9="lksctp-tools-1.0.19-2.el9.x86_64.rpm"            # 1.0.19-3 (RHEL 9.4 GA)
libgcc_9="libgcc-11.5.0-2.el9.x86_64.rpm"                  # 11.4.1-3 (RHEL 9.4 GA)
glibc_9="glibc-2.34-122.el9.x86_64.rpm"                    # 2.34-100 (RHEL 9.4 GA)
glibccom_9="glibc-common-2.34-122.el9.x86_64.rpm"          # 2.34-100 (RHEL 9.4 GA)
glibclang_9="glibc-all-langpacks-2.34-122.el9.x86_64.rpm"  # 2.34-100 (RHEL 9.4 GA)
openssl_9="openssl-libs-3.2.2-6.el9.x86_64.rpm"            # 3.0.7-27 (RHEL 9.4 GA)
zlib_9="zlib-1.2.11-41.el9.i686.rpm"                       # 1.2.11-40 (RHEL 9.4 GA)

# RHEL 10 packages 
iperf_10="iperf3-3.17.1-2.el10.x86_64.rpm"
lksctp_10="lksctp-tools-1.0.19-7.el10.x86_64.rpm"
libgcc_10="libgcc-14.2.1-1.el10.x86_64.rpm"                # 14.2.1-1 (RHEL 10 nightly_0902)
glibc_10="glibc-2.39-17.el10.x86_64.rpm"                   # 2.39-17 (RHEL 10 nightly_0902)
glibccom_10="glibc-common-2.39-17.el10.x86_64.rpm"         # 2.39-17 (RHEL 10 nightly_0902)
glibclang_10="glibc-all-langpacks-2.39-17.el10.x86_64.rpm" # 2.39-17 (RHEL 10 nightly_0902)
openssl_10="openssl-libs-3.2.2-12.el10.x86_64.rpm"         # 3.2.2-11 (RHEL 10 nightly_0902)
zlib_10="zlib-ng-compat-2.1.6-3.el10.x86_64.rpm"           # 2.1.6-3 (RHEL 10 nightly_08xx)


# Restrict user account
[[ $EUID == 0 ]] && echo -e "⚠️ Please run as non-root user.\n" && exit


# Check Internet connection
CheckNetwork() {
    ! nslookup "hp.com" > /dev/null && echo "❌ No Internet connection! Please check your network" && sleep 3 && exit
}

# Check the update and download binaries
UpdateScript() {
    release_url=https://api.github.com/repos/DreamCasterX/WLAN-Tput-Check/releases/latest
    new_version=$(wget -qO- "${release_url}" | grep '"tag_name":' | awk -F\" '{print $4}')
    release_note=$(wget -qO- "${release_url}" | grep '"body":' | awk -F\" '{print $4}')
    tarball_url="https://github.com/DreamCasterX/WLAN-Tput-Check/archive/refs/tags/${new_version}.tar.gz"
    if [[ $new_version != $__version__ ]]; then
        echo -e "⭐️ New version found!\n\nVersion: $new_version\nRelease note:\n$release_note"
        sleep 2
        echo -e "\nDownloading update..."
        pushd "$PWD" > /dev/null 2>&1
        wget --quiet --no-check-certificate --tries=3 --waitretry=2 --output-document=".WLAN-Tput-Check.tar.gz" "${tarball_url}"
        if [[ -e ".WLAN-Tput-Check.tar.gz" ]]; then
	    tar -xf .WLAN-Tput-Check.tar.gz -C "$PWD" --strip-components 1 > /dev/null 2>&1
	    rm -f .WLAN-Tput-Check.tar.gz
            popd > /dev/null 2>&1
            sleep 3
            sudo chmod 755 TputCheck.sh
            echo -e "Successfully updated! Please run TputCheck.sh again.\n\n" ; exit 1
        else
            echo -e "\n❌ Error occurred while downloading" ; exit 1
        fi 
    else
        if [[ ! -d ./rhcert ]]; then
            echo -e "\nDownloading test binaries....\n"
            pushd "$PWD" > /dev/null 2>&1
            wget --quiet --no-check-certificate --tries=3 --waitretry=2 --output-document=".WLAN-Tput-Check.tar.gz" "${tarball_url}"
            if [[ -e ".WLAN-Tput-Check.tar.gz" ]]; then
	        tar -xf .WLAN-Tput-Check.tar.gz -C "$PWD" --strip-components 1 WLAN-Tput-Check-$new_version/rhcert > /dev/null 2>&1
                rm -f .WLAN-Tput-Check.tar.gz
                popd > /dev/null 2>&1
                sleep 3
                sudo chmod 755 -R ./rhcert
                echo -e "\e[32mDone!\e[0m"
            else
                echo -e "\n\e[31mDownload test binaries failed.\e[0m" ; exit 1
            fi	
        fi		
    fi
}

echo -e "\n[HP WiFi Throughput Test Utility]\n" 
CheckNetwork
UpdateScript


# Remote install
[[ -f /usr/bin/apt ]] && PKG=apt || PKG=dnf
case $PKG in
"apt")
    if [[ ! -f /usr/bin/iperf3 ]]; then
        CheckNetwork
        sudo apt update && sudo apt install ssh iperf3 -y
    fi
    ;;
"dnf")
    if [[ ! -f /usr/bin/iperf3 ]]; then
        OS_VERSION=`cat /etc/os-release | grep ^VERSION_ID= | awk -F= '{print $2}' | cut -d '"' -f2 | cut -d '.' -f1`
        rpm_link_BaseOS="https://rpmfind.net/linux/centos-stream/$OS_VERSION-stream/BaseOS/x86_64/os/Packages/"
        rpm_link_AppStream="https://rpmfind.net/linux/centos-stream/$OS_VERSION-stream/AppStream/x86_64/os/Packages/"
        if [[ $OS_VERSION == '9' ]]; then 
            CheckNetwork
            wget -P ./rhcert/rpm_9/ $rpm_link_AppStream$iperf_9 $rpm_link_BaseOS$lksctp_9 # $rpm_link_BaseOS$libgcc_9 $rpm_link_BaseOS$glibc_9 $rpm_link_BaseOS$glibccom_9 $rpm_link_BaseOS$glibclang_9 $rpm_link_BaseOS$openssl_9 $rpm_link_BaseOS$zlib_9
	    sudo rpm -ivh ./rhcert/rpm_9/*.rpm --force && sudo rm -fr ./rhcert/rpm_9
        elif [[ $OS_VERSION == '10' ]]; then 
            CheckNetwork
            wget -P ./rhcert/rpm_10/ $rpm_link_AppStream$iperf_10 $rpm_link_BaseOS$lksctp_10
	    sudo rpm -ivh ./rhcert/rpm_10/*.rpm --force && sudo rm -fr ./rhcert/rpm_10
        fi
    fi
    ;;
esac   
   

# Get partner client's IP
if [[ ! -f ./SUT_ip.txt ]]; then 
    read -p "Input partner client's IP (press Enter to use default: 192.168.1.3): " input 
    if [[ -z "$input" ]]; then
        echo "192.168.1.3" > SUT_ip.txt
    else
        echo "$input" > SUT_ip.txt 
    fi
fi
SUT_IP=$(cat ./SUT_ip.txt)


# Configure partner client's ports and firewall
Configure() {
    ssh -T $HOST_NAME@$SUT_IP << EOF
        # Run iperf3 server on partner client ports
        [[ ! -f /usr/bin/iperf3 ]] && echo -e "\n\e[31miperf3 tool is not installed on the partner client!\e[0m" && exit 1
        for port in \`seq 52001 52002\`; do iperf3 -s -D -p \$port; done

        # Stop firewall service based on OS
        if [[ -f /usr/sbin/firewalld ]]; then
            echo '$PASSWORD' | sudo -S systemctl stop firewalld.service
        elif [[ -f /usr/sbin/ufw ]]; then
            echo '$PASSWORD' | sudo -S systemctl stop ufw.service
        fi
        exit
EOF
    if [[ $? -ne 0 ]]; then
      echo -e "\n\e[31mFailed to configure partner client.\e[0m"
      exit 1
    fi
    touch .configured_$SUT_IP
} 

if [[ ! -f .configured_$SUT_IP ]]; then
    echo -e "\e[33mConfiguring partner client...\e[0m" 
    Configure
fi
    

# Run iperf test
echo -e "\n\e[33mStarting iperf test...\e[0m"
for port in `seq 52001 52002`; do iperf3 -c $SUT_IP -p $port -f m -T $port & done | tee iperf3_output.txt


# Get result
python3 rhcert/iperf3.py
rm -fr iperf3_output.txt


