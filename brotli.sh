#!/usr/bin/env bash

# version 1.1

# use it while developing / testing.
# you may use it in production as well.
# set -o errexit -o pipefail -o noclobber -o nounset
# set -x

# compile Nginx from the official repo with brotli compression

[ ! -d /root/log ] && mkdir /root/log

# logging everything
log_file=/root/log/brotli.log
exec > >(tee -a ${log_file} )
exec 2> >(tee -a ${log_file} >&2)

# Defining return code check function
check_result() {
    if [ $1 -ne 0 ]; then
        echo "Error: $2"
        exit $1
    fi
}

export DEBIAN_FRONTEND=noninteractive

printf '%-72s' "Updating apt repos..."
apt-get -qq update
echo done.

printf '%-72s' "Installing pre-requisites..."
apt-get -qq install dpkg-dev build-essential zlib1g-dev libpcre3 libpcre3-dev unzip
echo done.

codename=$(lsb_release -c -s)

# function to add the official Nginx.org repo
nginx_repo_add() {
    distro=$(gawk -F= '/^ID=/{print $2}' /etc/os-release)
    codename=$(lsb_release -c -s)
    if [ "$codename" == "juno" ] ; then
        codename=bionic
    fi

    if [ "$distro" == "elementary" ] ; then
        distro=ubuntu
    fi

    [ -f nginx_signing.key ] && rm nginx_signing.key
    curl -LSsO http://nginx.org/keys/nginx_signing.key
    check_result $? 'Nginx key could not be downloaded!'
    apt-key add nginx_signing.key &> /dev/null
    check_result $? 'Nginx key could not be added!'
    rm nginx_signing.key

    # for updated info, please see https://nginx.org/en/linux_packages.html#stable
    nginx_branch= # leave this empty to install stable version
    # or nginx_branch="mainline"

    if [ "$nginx_branch" == 'mainline' ]; then
        nginx_src_url="https://nginx.org/packages/mainline/${distro}/"
    else
        nginx_src_url="https://nginx.org/packages/${distro}/"
    fi

    [ -f /etc/apt/sources.list.d/nginx.list ] && rm /etc/apt/sources.list.d/nginx.list
    echo "deb ${nginx_src_url} ${codename} nginx" > /etc/apt/sources.list.d/nginx.list
    echo "deb-src ${nginx_src_url} ${codename} nginx" >> /etc/apt/sources.list.d/nginx.list

    # finally update the local apt cache
    apt-get update -qq
    check_result $? 'Something went wrong while updating apt repos.'
}

case "$codename" in
    "stretch")
        nginx_repo_add
        ;;
    "xenial")
        nginx_repo_add
        ;;
    "bionic")
        nginx_repo_add
        ;;
    "juno")
        codename=bionic
        nginx_repo_add
        ;;
    *)
        echo "Distro: $codename"
        echo 'Warning: Could not figure out the distribution codename. Continuing to install Nginx from the OS.'
        ;;
esac

cd /usr/local/src
apt-get source nginx
apt-get build-dep nginx -y

git clone --recursive https://github.com/eustas/ngx_brotli

cd /usr/local/src/nginx-*/

# modify the existing config
grep -wq '--add-module=/usr/local/src/ngx_brotli' debian/rules || sed -i -e '/\.\/configure/ s:$: --add-module=/usr/local/src/ngx_brotli:' debian/rules

# build the updated pacakge
dpkg-buildpackage -b

# optional
# install the updated package in the current server
cd /usr/local/src
dpkg -i nginx*.deb

# take a backup
[ ! -d ~/backups/ ] && mkdir ~/backups
cp nginx*.deb ~/backups/nginx-$(date +%F)/

# remove all the sources and apt sources file
cd ~/
rm -rf /usr/local/src/nginx*
rm -rf /usr/local/src/ngx_brotli
rm /etc/apt/sources.list.d/nginx.list
apt-get -qq update

# hold the package nginx from updating accidentally in the future by someone else!
apt-mark hold nginx

# stop the previously running instance, if any
nginx -t && systemctl stop nginx

# start the new Nginx instance
nginx -t && systemctl start nginx
