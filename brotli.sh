#!/usr/bin/env bash

# version 2.1

# version 2.1
#   date: 2021-04-27
#   changes:
#   - fix minor issues
# version 2
#   date: 2021-04-27
#   changes:
#   - migrate to Google repo
#   - test with Ubuntu 20.04

# use it while developing / testing.
# set -o errexit -o pipefail -o noclobber -o nounset
# set -x

# compile Nginx from the official repo with brotli compression

[ ! -d ${HOME}/log ] && mkdir ${HOME}/log

G_DIR="$(pwd)"

# logging everything
log_file=${HOME}/log/brotli.log
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
sudo apt-get -qq update
echo done.

printf '%-72s' "Installing pre-requisites..."
sudo apt-get -qq install dpkg-dev build-essential zlib1g-dev libpcre3 libpcre3-dev unzip
echo done.

codename=$(lsb_release -cs)

# function to add the official Nginx.org repo
nginx_repo_add() {
    distro=$(gawk -F= '/^ID=/{print $2}' /etc/os-release)
    if [ "$codename" == "juno" ] ; then
        codename=bionic
    fi

    if [ "$distro" == "elementary" ] ; then
        distro=ubuntu
    fi

    if [ "$distro" == "linuxmint" ] ; then
        distro=ubuntu
    fi

    # Remove old key if it exists
    curl -LSs -o /tmp/nginx_signing.key http://nginx.org/keys/nginx_signing.key
        check_result $? 'Nginx key could not be downloaded!'
    sudo apt-key add /tmp/nginx_signing.key &> /dev/null
        check_result $? 'Nginx key could not be added!'
    sudo mv /tmp/nginx_signing.key /etc/apt/trusted.gpg.d/nginx_signing.asc
        check_result $? 'Nginx key could not be added to apt trusted key storage!'

    # for updated info, please see https://nginx.org/en/linux_packages.html#stable
    nginx_branch= # leave this empty to install stable version
    # or nginx_branch="mainline"

    if [ "$nginx_branch" == 'mainline' ]; then
        nginx_src_url="https://nginx.org/packages/mainline/${distro}/"
    else
        nginx_src_url="https://nginx.org/packages/${distro}/"
    fi

    [ -f /etc/apt/sources.list.d/nginx.list ] && sudo rm /etc/apt/sources.list.d/nginx.list
    echo "deb [arch=amd64] ${nginx_src_url} ${codename} nginx" | sudo tee /etc/apt/sources.list.d/nginx.list &> /dev/null
    echo "deb-src [arch=amd64] ${nginx_src_url} ${codename} nginx" | sudo tee -a /etc/apt/sources.list.d/nginx.list &> /dev/null

    # finally update the local apt cache
    sudo apt-get update -qq
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
    "focal")
        nginx_repo_add
        ;;
    "juno")
        codename=bionic
        nginx_repo_add
        ;;
     "tara")
        codename=bionic
        nginx_repo_add
        ;;
    *)
        echo "Distro: $codename"
        echo 'Warning: Could not figure out the distribution codename. Continuing to install Nginx from the OS.'
        ;;
esac

sudo install -o ${UID} -g $(id -gn $USER) -d /usr/local/src/${USER}
cd /usr/local/src/${USER}
sudo apt-get source nginx
sudo apt-get build-dep nginx -y

if [ ! -d ngx_brotli ]; then
    git clone -q --recursive https://github.com/google/ngx_brotli
else
    git -C ngx_brotli pull -q origin master
fi

[ -L /usr/local/src/ngx_brotli ] && sudo rm /usr/local/src/ngx_brotli
sudo ln -s /usr/local/src/${USER}/ngx_brotli /usr/local/src/ngx_brotli
sudo chown ${USER}:$USER /usr/local/src/ngx_brotli
cd /usr/local/src/${USER}/nginx-*/

# modify the existing config
sed -i -e '/\.\/configure/ s:$: --add-module=/usr/local/src/ngx_brotli:' debian/rules

# if gcc 8 is installed add patch to nginx 
if [ "$(gcc -dumpversion)" == "8" ]; then
    mkdir -p debian/patches
    cp ${G_DIR}/gcc-8_fix.diff debian/patches/gcc-8_fix
    echo "gcc-8_fix" > debian/patches/series
fi

# build the updated pacakge
dpkg-buildpackage -b

# optional
# install the updated package in the current server
cd /usr/local/src/${USER}
sudo dpkg -i nginx_*.deb

# take a backup
[ ! -d ~/backups/nginx-$(date +%F) ] && mkdir -p ~/backups/nginx-$(date +%F)
cp nginx*.deb ~/backups/nginx-$(date +%F)/

# print info about remove all the sources and apt sources file
cd ~/

printf "
# To clean up after install You can run
 rm -rf /usr/local/src/$(echo ${USER})/nginx*
 rm -rf /usr/local/src/$(echo ${USER})/ngx_brotli
 sudo rm /etc/apt/sources.list.d/nginx.list
 sudo apt-get -qq update
"
# hold the package nginx from updating accidentally in the future by someone else!
sudo apt-mark hold nginx
sudo apt-mark hold nginx-dbg

# stop the previously running instance, if any
sudo nginx -t && sudo systemctl stop nginx

# start the new Nginx instance
sudo nginx -t && sudo systemctl start nginx

echo 'All done.'
