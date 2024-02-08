#!/bin/bash

set -euo pipefail

# Assumes running as root / sudo
# Instead of user "flux" we are going to do everything as ubuntu

echo "START flux build"

# Install dependencies (might be some left over from BDF)
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update && \
    sudo apt-get upgrade -y && \
    sudo apt-get install -y apt-transport-https ca-certificates curl clang llvm jq apt-utils wget \
         libelf-dev libpcap-dev libbfd-dev binutils-dev build-essential make \
         linux-tools-common linux-tools-$(uname -r)  \
         bpfcc-tools python3-pip git net-tools

# cmake is needed for flux now!
export CMAKE=3.23.1
curl -s -L https://github.com/Kitware/CMake/releases/download/v$CMAKE/cmake-$CMAKE-linux-x86_64.sh > cmake.sh && \
    sudo sh cmake.sh --prefix=/usr/local --skip-license && \
    sudo apt-get install -y man flex ssh sudo vim luarocks munge lcov ccache lua5.2 mpich \
         valgrind build-essential pkg-config autotools-dev libtool \
         libffi-dev autoconf automake make clang clang-tidy \
         gcc g++ libpam-dev apt-utils \
         libsodium-dev libzmq3-dev libczmq-dev libjansson-dev libmunge-dev \
         libncursesw5-dev liblua5.2-dev liblz4-dev libsqlite3-dev uuid-dev \
         libhwloc-dev libmpich-dev libs3-dev libevent-dev libarchive-dev \
         libboost-graph-dev libboost-system-dev libboost-filesystem-dev \
         libboost-regex-dev libyaml-cpp-dev libedit-dev uidmap dbus-user-session

# Let's use mamba python and do away with system annoyances
export PATH=/opt/conda/bin:$PATH
curl -L https://github.com/conda-forge/miniforge/releases/latest/download/Mambaforge-Linux-x86_64.sh > mambaforge.sh && \
    sudo bash mambaforge.sh -b -p /opt/conda && \
    sudo chown $USER -R /opt/conda && \
    pip install --upgrade --ignore-installed markupsafe coverage cffi ply six pyyaml jsonschema && \
    pip install --upgrade --ignore-installed sphinx sphinx-rtd-theme sphinxcontrib-spelling

# Prepare lua rocks things I don't understand
sudo apt-get install -y faketime libfaketime pylint cppcheck aspell aspell-en && \
    sudo locale-gen en_US.UTF-8 && \
    sudo luarocks install luaposix

# openpmix... back... back evil spirits!
sudo chown -R $USER /opt && \
    mkdir -p /opt/prrte && \
    cd /opt/prrte && \
    git clone https://github.com/openpmix/openpmix.git && \
    git clone https://github.com/openpmix/prrte.git && \
    set -x && \
    cd openpmix && \
    git checkout fefaed568f33bf86f28afb6e45237f1ec5e4de93 && \
    ./autogen.pl && \
    ./configure --prefix=/usr --disable-static && sudo make -j 4 install && \
    sudo ldconfig

# prrte you are sure looking perrrty today
cd /opt/prrte/prrte && \
    git checkout 477894f4720d822b15cab56eee7665107832921c && \
    ./autogen.pl && \
    ./configure --prefix=/usr && sudo make -j 4 install

# flux security
git clone --depth 1 https://github.com/flux-framework/flux-security /opt/flux-security && \
    cd /opt/flux-security && \
    ./autogen.sh && \
    PYTHON=/opt/conda/bin/python ./configure --prefix=/usr --sysconfdir=/etc && \
    make && sudo make install

# The VMs will share the same munge key
sudo mkdir -p /var/run/munge && \
    dd if=/dev/urandom bs=1 count=1024 > munge.key && \
    sudo mv munge.key /etc/munge/munge.key && \
    sudo chown -R munge /etc/munge/munge.key /var/run/munge && \
    sudo chmod 600 /etc/munge/munge.key

# Make the flux run directory
mkdir -p /home/ubuntu/run/flux

# Flux core
git clone https://github.com/flux-framework/flux-core /opt/flux-core && \
    cd /opt/flux-core && \
    ./autogen.sh && \
    PYTHON=/opt/conda/bin/python PYTHON_PREFIX=PYTHON_EXEC_PREFIX=/opt/conda/lib/python3.8/site-packages ./configure --prefix=/usr --sysconfdir=/etc --runstatedir=/home/flux/run --with-flux-security && \
    make clean && \
    make && sudo make install

# Flux sched
git clone https://github.com/flux-framework/flux-sched /opt/flux-sched && \
    cd /opt/flux-sched && \
    git fetch && \
    ./autogen.sh && \
    PYTHON=/opt/conda/bin/python ./configure --prefix=/usr --sysconfdir=/etc && \
    make && sudo make install && ldconfig && \
    echo "DONE flux build"

# Flux curve.cert
# Ensure we have a shared curve certificate
flux keygen /tmp/curve.cert && \
    sudo mkdir -p /etc/flux/system && \
    sudo cp /tmp/curve.cert /etc/flux/system/curve.cert && \
    sudo chown ubuntu /etc/flux/system/curve.cert && \
    sudo chmod o-r /etc/flux/system/curve.cert && \
    sudo chmod g-r /etc/flux/system/curve.cert && \
    # Permissions for imp
    sudo chmod u+s /usr/libexec/flux/flux-imp && \
    sudo chmod 4755 /usr/libexec/flux/flux-imp && \
    # /var/lib/flux needs to be owned by the instance owner
    sudo mkdir -p /var/lib/flux && \
    sudo chown -R /var/lib/flux && \
    # clean up
    cd /
    # sudo rm -rf /opt/flux-core /opt/flux-sched /opt/prrte /opt/flux-security