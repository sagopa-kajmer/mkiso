#!/bin/bash
umask 022
set -e
if [[ ! -d build ]] ; then
    rm -rf build
fi
# fetch & extract rootfs
mkdir -p build
cd build
uri="https://dl-cdn.alpinelinux.org/alpine/edge/releases/$(uname -m)/"
tarball=$(wget -O - "$uri" |grep "alpine-minirootfs" | grep "tar.gz<" | \
    sort -V | tail -n 1 | cut -f2 -d"\"")
wget -O "$tarball" "$uri/$tarball"
mkdir -p chroot
cd chroot
tar -xvf ../*$tarball
# fix resolv.conf
install /etc/resolv.conf ./etc/resolv.conf
# add repositories
cat > ./etc/apk/repositories <<EOF
https://dl-cdn.alpinelinux.org/alpine/edge/main
https://dl-cdn.alpinelinux.org/alpine/edge/community
https://dl-cdn.alpinelinux.org/alpine/edge/testing
https://dl-cdn.alpinelinux.org/alpine/latest-stable/main
https://dl-cdn.alpinelinux.org/alpine/latest-stable/community
EOF
# upgrade if needed
chroot ./ apk upgrade
# hooks
cd ../../hooks
for file in $(ls . | sort -V) ; do
    echo "Executing: $file"
    install $file ../build/chroot/tmp/hook
    chroot ../build/chroot/ ash /tmp/hook
done
if [[ -d ../build/isowork ]] ; then
    rm -rf ../build/isowork
fi
# copy rootfs files
cp -rf ../airootfs/* ../build/chroot/ || true
mkdir -p ../build/isowork/live
cd ../build/isowork
# copy kernel
install ../chroot/boot/vmlinuz-edge vmlinuz-edge
install ../chroot/boot/initramfs-live initramfs-live
# remove initrd from squashfs
rm ../chroot/boot/initramfs-*
# create squashfs
mksquashfs ../chroot live/filesystem.squashfs -comp gzip -wildcards
# create grub config
mkdir -p boot/grub/
cat > boot/grub/grub.cfg <<EOF
insmod all_video
terminal_output console
terminal_input console
menuentry "Sagopa Kajmer Linux" {
    linux /vmlinuz-edge quiet boot=live
    initrd /initramfs-live
}
EOF
# create iso
cd ../
grub-mkrescue isowork -o alpine.iso
