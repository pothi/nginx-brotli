#!/usr/bin/env bash

# version 1.0

# changelog
# version 1.0
#   - first version

# you may use the following while developing / testing.
# set -o errexit -o pipefail -o noclobber -o nounset
# set -x

# compile Nginx for naxsi

### variables ###

# get the latest version at https://www.openssl.org/source/
openssl_version='1.1.1l'

### end of variables ###

[ ! -d ${HOME}/log ] && mkdir ${HOME}/log

G_DIR="$(pwd)"

# log everything
log_file=${HOME}/log/brotli.log
exec > >(tee -a ${log_file} )
exec 2> >(tee -a ${log_file} >&2)

export DEBIAN_FRONTEND=noninteractive

echo "Script started on (date & time): $(date +%c)"

# helper function/s
check_result() {
    if [ $1 -ne 0 ]; then
        echo "Error: $2"
        exit $1
    fi
}

install_package() {
    if dpkg-query -s $1 &> /dev/null
        then
            echo "$1 is already installed"
        else
            printf '%-72s' "Installing ${1}..."
            sudo apt-get -qq install $1 &> /dev/null
            echo done.
    fi
}

# function to add the official Nginx.org repo
nginx_repo_add() {
    distro=$(gawk -F= '/^ID=/{print $2}' /etc/os-release)

    if [ "$distro" == "elementary" ] ; then
        distro=ubuntu
    fi

    if [ "$distro" == "linuxmint" ] ; then
        distro=ubuntu
    fi

    [ -f nginx_signing.key ] && rm nginx_signing.key
    curl -LSsO http://nginx.org/keys/nginx_signing.key
    check_result $? 'Nginx key could not be downloaded!'
    sudo apt-key add nginx_signing.key &> /dev/null
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

    [ -f /etc/apt/sources.list.d/nginx-tmp.list ] && sudo rm /etc/apt/sources.list.d/nginx-tmp.list
    echo "deb ${nginx_src_url} $1 nginx" | sudo tee /etc/apt/sources.list.d/nginx-tmp.list
    echo "deb-src ${nginx_src_url} $1 nginx" | sudo tee -a /etc/apt/sources.list.d/nginx-tmp.list

    # finally update the local apt cache
    sudo apt-get update -qq
    check_result $? 'Something went wrong while updating apt repos.'
}

printf '%-72s' "Updating apt repos..."
sudo apt-get -qq update
echo done.

echo "Installing pre-requisites..."
echo -----------------------------------------------------------------------------

required_packages="dpkg-dev build-essential zlib1g-dev libpcre3 libpcre3-dev unzip mercurial"
for package in $required_packages
do
    install_package $package
done

echo -----------------------------------------------------------------------------
echo ... done installing pre-requisites.

codename=$(lsb_release -c -s)

case "$codename" in
    "bullseye")
        nginx_repo_add $codename
        ;;
    "stretch")
        nginx_repo_add $codename
        ;;
    "xenial")
        nginx_repo_add $codename
        ;;
    "bionic")
        nginx_repo_add $codename
        ;;
    "focal")
        nginx_repo_add $codename
        ;;
    "juno")
        codename=bionic
        nginx_repo_add $codename
        ;;
     "tara")
        codename=bionic
        nginx_repo_add $codename
        ;;
    *)
        echo "Distro: $codename"
        echo 'Warning: Could not figure out the distribution codename. Exiting now.'
        exit 3
        ;;
esac

#------------------------- Download Sources ------------------------

sudo install -o ${UID} -g $(id -gn $USER) -d /usr/local/src/${USER}
cd /usr/local/src/${USER}
apt-get source nginx
sudo apt-get build-dep nginx -y

# download sources - 
export NAXSI_VER=1.3
if [ ! -d "/usr/local/src/${USER}/naxsi-$NAXSI_VER" ]; then
    wget https://github.com/nbs-system/naxsi/archive/$NAXSI_VER.tar.gz -O naxsi_$NAXSI_VER.tar.gz
    wget https://github.com/nbs-system/naxsi/releases/download/$NAXSI_VER/naxsi-$NAXSI_VER.tar.gz.asc -O naxsi_$NAXSI_VER.tar.gz.asc
    gpg --keyserver keyserver.ubuntu.com --recv-key 498C46FF087EDC36E7EAF9D445414A82A9B22D78
    gpg --verify naxsi_$NAXSI_VER.tar.gz.asc
    rm naxsi_$NAXSI_VER.tar.gz.asc
fi

tar xf naxsi_$NAXSI_VER.tar.gz

#-------------------------

cd /usr/local/src/${USER}/nginx-*/

if [ -f "debian/rules-ori" ]; then
    cp debian/rules-ori debian/rules
else
    cp debian/rules debian/rules-ori
fi

# modify the existing config
# sed -i -e "/\.\/configure/ s:$: --add-dynamic-module=/usr/local/src/${USER}/naxsi-$NAXSI_VER/naxsi_src/:" debian/rules
# https://github.com/openssl/openssl/issues/5955#issuecomment-381391131
sed -i -e 's/^DPKG_EXPORT_BUILDFLAGS/# &/g' debian/rules

# if gcc 8 is installed add patch nginx 
if [ "$(gcc -dumpversion)" == "8" ]; then
    if [ -f "${G_DIR}/dcc-8_fix.diff" ]; then
        mkdir -p debian/patches
        cp ${G_DIR}/gcc-8_fix.diff debian/patches/gcc-8_fix
        echo "gcc-8_fix" > debian/patches/series
    fi
fi

# build the updated pacakge
sudo dpkg-buildpackage -b

# optional
# install the updated package in the current server
cd /usr/local/src/${USER}

sudo apt-mark unhold nginx
sudo dpkg -i nginx*.deb

compile_args=$(nginx -V 2>&1 | grep '^configure' | sed 's/configure arguments: //')
echo $compile_args

cd /usr/local/src/${USER}/nginx-*/
./configure "$compile_args" --add-dynamic-module=/usr/local/src/${USER}/naxsi-$NAXSI_VER/naxsi_src/
# make modules
sudo make modules
sudo cp objs/ngx_http_naxsi_module.so /etc/nginx/modules/
sudo cp /usr/local/src/root/naxsi-${NAXSI_VER}/naxsi_config/naxsi_core.rules /etc/nginx/
cd /usr/local/src/${USER}

# take a backup
[ ! -d ~/backups/  ] && mkdir ~/backups
[ ! -d ~/backups/nginx-$(date +%F) ] && mkdir ~/backups/nginx-$(date +%F)
cp nginx*.deb ~/backups/nginx-$(date +%F)/

# print info about remove all the sources and apt sources file
cd

printf "
# To clean up after install, you can run
  rm -rf /usr/local/src/$(echo ${USER})/nginx*
  rm -rf /usr/local/src/$(echo ${USER})/ngx_brotli
  sudo rm /etc/apt/sources.list.d/nginx-tmp.list
  sudo apt-get -qq update
"
sudo rm -rf /usr/local/src/${USER}/nginx-*

# hold the package nginx from updating accidentally in the future by someone else!
sudo apt-mark hold nginx

# stop the previously running instance, if any
sudo nginx -t && sudo systemctl stop nginx &> /dev/null

# start the new Nginx instance
sudo nginx -t && sudo systemctl start nginx

echo "Script ended on (date & time): $(date +%c)"


