#!/bin/sh

set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

exec 1> >(tee "stdout.log")
exec 2> >(tee "stderr.log" >&2)

# read .env
while read line; do export $line; done < .env

script_name="$(basename "$0")"
dotfiles_dir="$(
    cd "$(dirname "$0")"
    pwd
)"
cd "$dotfiles_dir"

echo -e "\n### checking network"

ping -c 1 8.8.8.8


echo -e "\n### setting up partitions"

umount -R /mnt 2> /dev/null || true

lsblk -plnx size -o name "${DEVICE}" | xargs -n1 wipefs --all
sgdisk --clear "${DEVICE}" --new 1::-551MiB "${DEVICE}" --new 2::0 --typecode 2:ef00 "${DEVICE}"
sgdisk --change-name=1:nixos --change-name=2:esp "${DEVICE}"

PART_ROOT="$(ls ${DEVICE}* | grep -E "^${DEVICE}p?1$")"
PART_BOOT="$(ls ${DEVICE}* | grep -E "^${DEVICE}p?2$")"

echo -e "\n### formatting partitions"

mkfs.vfat -n "esp" -F 32 "${PART_BOOT}"

mkfs.ext4 -L "nixos" "${PART_ROOT}"

echo -e "\n### mounting partitions"

mount -o noatime,nodiratime "${PART_ROOT}" /mnt

mkdir -p /mnt/boot
mount "${PART_BOOT}" /mnt/boot
