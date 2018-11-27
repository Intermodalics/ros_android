#!/bin/bash

# Abort script on any failures
set -e

my_loc="$(cd "$(dirname $0)" && pwd)"
source $my_loc/config.sh
source $my_loc/utils.sh

if [ $# != 2 ] || [ $1 == '-h' ] || [ $1 == '--help' ]; then
    echo "Usage: $0 library_name library_source_dir"
    echo "  example: $0 /home/user/my_workspace/libxml2-2.9.1"
    exit 1
fi

prefix=$(cd $2 && pwd)

cd $2

# Create a stand alone version of the android toolchain
echo
echo -e '\e[34mBuilding '$1'.\e[39m'
echo

[ "$CMAKE_PREFIX_PATH" = "" ] && die 'could not find target basedir. Have you run build_catkin.sh and sourced setup.bash?'

if [ ! -d toolchain/ ]; then
  $ANDROID_NDK/build/tools/make-standalone-toolchain.sh --install-dir=./toolchain --arch=$arch
fi
export PATH=$PATH:$2/toolchain/bin

# Set --host: The system where built programs and libraries will run.
# (https://www.gnu.org/software/automake/manual/html_node/Cross_002dCompilation.html)
build=`uname -m`-linux
host=$(basename $2/toolchain/*-linux-android)

# General options to pass to ./configure script
configure_options="--prefix=$CMAKE_PREFIX_PATH --disable-shared --enable-static --build=${build} --host=${host}"

# Overwrite/extend for specific packages
if [ $1 == 'poco' ]; then
    configure_options="--config=Android_static --no-samples --no-tests"
    export ANDROID_ABI=$abi
elif [ $1 == 'curl' ]; then
    configure_options="$configure_options --without-ssl --disable-tftp --disable-sspi --disable-ipv6 --disable-ldaps --disable-ldap --disable-telnet --disable-pop3 --disable-ftp --disable-imap --disable-smtp --disable-pop3 --disable-rtsp --disable-ares --without-ca-bundle --disable-warnings --disable-manual --without-nss --without-random"
elif [ $1 == 'libxml2' ]; then
    configure_options="$configure_options --without-python"
elif [ $1 == 'log4cxx' ]; then
    # config.guess and config.sub are out-of-date and do not support arm64 builds. Regenerate...
    rm -f config.guess config.sub
    autoreconf -i
elif [ $1 == 'apr-util' ]; then
    configure_options="$configure_options --with-apr=$CMAKE_PREFIX_PATH/bin/apr-1-config"
fi

# Configure and build
./configure ${configure_options}
make -j$PARALLEL_JOBS -l$PARALLEL_JOBS V=1

# Install
if [ $1 == 'poco' ]; then
    mkdir -p $CMAKE_PREFIX_PATH/lib
    cd $CMAKE_PREFIX_PATH/lib
    cp $prefix/lib/Android/$abi/lib*.a ./
    mkdir -p ../include && cd ../include
    cp -r $prefix/Foundation/include/Poco ./
else
    make install
fi
