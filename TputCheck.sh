#!/usr/bin/env bash

# CREATOR: mike.lu@hp.com
# CHANGE DATE: 2024/09/12
__version__="1.0"


# [WiFi Throughput Check Setup] 
# 1. Make sure you can log in to the Partner Client via SSH 
#	ssh <partner client’s user name>@<partner client’s IP>    e.g., ssh u@192.168.1.3
#
# 2. Run below command on Partner Client (one-time effort):
#	`for port in `seq 52001 52002`; do iperf3 -s -D -p $port; done`
#	(On RHEL):   `sudo systemctl stop firewalld.service`
#	(On Ubuntu): `sudo systemctl stop ufw.service`


# RHEL 9 packages 
# iperf_9="iperf3-3.9-13.el9.x86_64.rpm"                     # 3.9-10 (RHEL 9.4 GA)
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
Update_script() {
    release_url=https://api.github.com/repos/DreamCasterX/WLAN-Tput-Check/releases/latest
    new_version=$(curl -s "${release_url}" | grep '"tag_name":' | awk -F\" '{print $4}')
    release_note=$(curl -s "${release_url}" | grep '"body":' | awk -F\" '{print $4}')
    tarball_url="https://github.com/DreamCasterX/WLAN-Tput-Check/archive/refs/tags/${new_version}.tar.gz"
    if [[ $new_version != $__version__ ]]; then
        echo -e "⭐️ New version found!\n\nVersion: $new_version\nRelease note:\n$release_note"
        sleep 2
        echo -e "\nDownloading update..."
        pushd "$PWD" > /dev/null 2>&1
        curl --silent --insecure --fail --retry-connrefused --retry 3 --retry-delay 2 --location --output ".WLAN-Tput-Check.tar.gz" "${tarball_url}"
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
Update_script


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
            wget -P ./rhcert/rpm_9/ $rpm_link_AppStream$iperf_9 $rpm_link_BaseOS$lksctp_9 $rpm_link_BaseOS$libgcc_9 $rpm_link_BaseOS$glibc_9 $rpm_link_BaseOS$glibccom_9 $rpm_link_BaseOS$glibclang_9 $rpm_link_BaseOS$openssl_9 $rpm_link_BaseOS$zlib_9
	    sudo rpm -ivh ./rhcert/rpm_9/*.rpm 
        elif [[ $OS_VERSION == '10' ]]; then 
            CheckNetwork
            wget -P ./rhcert/rpm_10/ $rpm_link_AppStream$iperf_10 $rpm_link_BaseOS$lksctp_10
	    sudo rpm -ivh ./rhcert/rpm_10/*.rpm && sudo rm -fr ./rhcert/rpm_10
        fi
    fi
    ;;
esac   
   

## Local install (RHEL only)
# if [[ ! -f /usr/bin/iperf3 ]]; then
#     if [[ $OS_VERSION == '9' ]]; then 
#         CheckNetwork && sudo rpm -ivh ./rhcert/rpm_9/*.rpm || :
#     elif [[ $OS_VERSION == '10' ]]; then 
#         CheckNetwork && sudo rpm -ivh ./rhcert/rpm_10/*.rpm || :
#     fi
# fi


# Get partner client's IP
[[ ! -f ./SUT_ip.txt ]] && read -p "Input partner client's IP: " SUT_IP && echo $SUT_IP > SUT_ip.txt || SUT_IP=`cat ./SUT_ip.txt`


# Run iperf test
for port in `seq 52001 52002`; do iperf3 -c $SUT_IP -p $port -f m -T $port & done | tee iperf3_output.txt


# Get result
python3 rhcert/iperf3.py


