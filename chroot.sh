#!/bin/bash
TARGET="$PWD/rootfs"
TERMUX_DIR="$TARGET/data/data/com.termux/files"

chroot_add_mount() {
  mkdir -p "$2"
  mount "$@" && CHROOT_ACTIVE_MOUNTS=("$2" "${CHROOT_ACTIVE_MOUNTS[@]}")
}

chroot_setup() {
  echo "Setup service.."
  CHROOT_ACTIVE_MOUNTS=()
  [[ $(trap -p EXIT) ]] && die '(BUG): attempting to overwrite existing EXIT trap'
  trap 'chroot_teardown' EXIT

  chroot_add_mount proc "$1/proc" -t proc -o nosuid,noexec,nodev
  chroot_add_mount sys "$1/sys" -t sysfs -o nosuid,noexec,nodev,ro
  chroot_add_mount udev "$1/dev" -t devtmpfs -o mode=0755,nosuid
  chroot_add_mount devpts "$1/dev/pts" -t devpts -o mode=0620,gid=5,nosuid,noexec
  chroot_add_mount shm "$1/dev/shm" -t tmpfs -o mode=1777,nosuid,nodev
}

chroot_teardown() {
    echo "Cleaning service.."
  if (( ${#CHROOT_ACTIVE_MOUNTS[@]} )); then
    umount "${CHROOT_ACTIVE_MOUNTS[@]}"
  fi
  unset CHROOT_ACTIVE_MOUNTS
}

chroot_setup "$TARGET" || exit 1

unshare --fork --pid chroot --userspec=1000:1000 "$TARGET" \
    env -i /usr/bin/login "$@"
