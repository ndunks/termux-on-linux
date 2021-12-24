#!/bin/bash
# Host OS: Debian
# Target: Chroot TMUX
set -e
SYSTEM_TYPE=x86
CURRENT_DIR="$PWD";
TARGET="$PWD/rootfs"
TERMUX_DIR="$TARGET/data/data/com.termux/files"

if [ ! -e termux-docker ]; then
    git clone --single-branch --depth 1 git@github.com:termux/termux-docker.git
fi

if [ ! -d $TARGET ]; then
    mkdir -p $TARGET
    # Copy libc, linker and few utilities.
    cp -rav termux-docker/system/$SYSTEM_TYPE $TARGET/system
    # Static DNS hosts: as our system does not have a DNS resolver, we will
    # have to resolve domains manually and fill /system/etc/hosts.
    cp termux-docker/static-dns-hosts.txt $TARGET/system/etc/static-dns-hosts.txt
fi

# Extract bootstrap archive and create symlinks.
if [ ! -e $CURRENT_DIR/bootstrap-x86_64.zip ]; then
    wget -q -O $CURRENT_DIR/bootstrap-x86_64.zip https://github.com/termux/termux-packages/releases/download/bootstrap-2021.12.19-r1/bootstrap-x86_64.zip
fi

mkdir -p $TERMUX_DIR
pushd $TERMUX_DIR
mkdir -p ../cache ./usr ./home
unzip -d usr $CURRENT_DIR/bootstrap-x86_64.zip
popd

if [ ! -f $TERMUX_DIR/usr ]; then
    pushd $TERMUX_DIR/usr
    cat SYMLINKS.txt | while read -r line; do
        dest=$(echo "$line" | awk -F '←' '{ print $1 }');
        link=$(echo "$line" | awk -F '←' '{ print $2 }');
        ln -fs "$dest" "$link";
    done
    rm SYMLINKS.txt
    popd
fi

sudo ln -s /data/data/com.termux/files/usr $TARGET/usr
sudo ln -s /data/data/com.termux/files/usr/bin $TARGET/bin
sudo ln -s /data/data/com.termux/files/usr/tmp $TARGET/tmp

sudo chown -Rh 0:0 $TARGET
sudo chown -Rh 1000:1000 $TARGET/data/data/com.termux
sudo chown 1000:1000 $TARGET/system/etc/hosts $TARGET/system/etc/static-dns-hosts.txt
find $TARGET/system -type d -exec sudo chmod 755 "{}" \;
find $TARGET/system -type f -executable -exec sudo chmod 755 "{}" \;
find $TARGET/system -type f ! -executable -exec sudo chmod 644 "{}" \;
find $TARGET/data -type d -exec sudo chmod 755 "{}" \;
find $TERMUX_DIR -type f -o -type d -exec sudo chmod g-rwx,o-rwx "{}" \;

pushd $TERMUX_DIR/usr

find ./bin ./lib/apt ./lib/bash ./libexec -type f -exec sudo chmod 700 "{}" \;

popd

sudo tee $TERMUX_DIR/usr/etc/profile.d/chroot-cfg.sh <<EOF
export PATH=\$PATH:/data/data/com.termux/files/usr/bin:/system/bin
export ANDROID_DATA=/data
export ANDROID_ROOT=/system
export HOME=/data/data/com.termux/files/home
export LANG=en_US.UTF-8
export PATH=/data/data/com.termux/files/usr/bin
export PREFIX=/data/data/com.termux/files/usr
export TMPDIR=/data/data/com.termux/files/usr/tmp
export TZ=UTC
export SHELL=/data/data/com.termux/files/usr/bin/sh
EOF

sudo chmod +x $TERMUX_DIR/usr/etc/profile.d/chroot-cfg.sh
sudo sed -i 's/deb /deb [trusted=yes] /g' $TERMUX_DIR/usr/etc/apt/sources.list
sudo ./chroot.sh sh -c 'apt update && \
    apt --allow-unauthenticated -y upgrade && \
    apt install --allow-unauthenticated -y termux-keyring'
