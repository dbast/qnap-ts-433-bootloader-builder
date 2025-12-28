# Debian Trixie Network Installer

Works with the 1 GBit Ethernet connection or an USB network adapter. No serial console required, but recommended.

Steps:

- Run `./prepare.sh` to download kernel/initrd and embed the preseed.cfg file.
- Create an USB device with one ext4/FAT32 partition.
- Copy the content of this folder to the root of the USB partition.
- Boot the device with the USB device inserted. u-boot finds the extlinux.conf and boots the installer.
- Connect via SSH: `ssh installer@$IP`, password: `1234`.
