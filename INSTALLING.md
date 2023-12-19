# Building the meticulous sdcard

The Image building process was targeted to **Ubuntu 23.10** as it is using its respective version
of GNU parted as well as other dependencies. On different operating systems you might want to use
a container or chroot for building.

## Installing host dependencies:
```
sudo apt -y install binfmt-support pv qemu-user-static debootstrap kpartx lvm2 dosfstools gpart binutils git libncurses-dev python3-m2crypto gawk wget git-core diffstat unzip texinfo gcc-multilib build-essential chrpath socat libsdl1.2-dev autoconf libtool libglib2.0-dev libarchive-dev python3-git xterm sed cvs subversion coreutils texi2html docbook-utils help2man make gcc g++ desktop-file-utils libgl1-mesa-dev libglu1-mesa-dev mercurial automake groff curl lzop asciidoc u-boot-tools mtd-utils libgnutls28-dev flex bison libssl-dev
```

## Installing the sources
After cloning this repo you will need to checkout the latest sources.
The `var_make_debian.sh` script can do so for you when beeing passed -c deploy

```
sudo ./var_make_debian.sh -c deploy
```

## Building the rootfs
After checking out the source the rootfs can be build:
```
sudo ./var_make_debian.sh -c all
```
The target `all` will build the u-boot the kernel with its modules and dtbs and debootstrap
a working rootfs. The resulting rootfs will then be compressed to a tar.gz and placed in output/

## Building the Image
A non A/B boot sdcard can be imaged with the `var_make_debian.sh` script, while the `build_img.sh` script
is designed to build an image with 5 partitions for u-boot env and A/B boot.

```
sudo ./var_make_debian.sh -c sdcard --dev /dev/sdX
```

OR

```
sudo ./build_img.sh
```

Resuling in an sdcard.img and sdcard.img.gz.
`build_img.sh` can also be modified to immediatly write to an sdcard by changing the `IMAGE_TARGET` variable.


## Rebuilding individual components
### u-boot
For the moment the u-boot.bin is build by NXPs `mkimage` and not the prefered upstream solution which is `binman`.
As mkimage requires a good bit of setup it is easier to have the variscite toolchain build the bootload for us:

```
sudo ./var_make_debian.sh -c bootloader
```
This will load the correct defconfig into `.config` and build the full u-boot with the correct
ATF (arm-trusted-firmware) as well as the correct firmware and assemble the u-boot finale image into `output/`


The resoluting image can then be flashed to an sdcard:
```
sudo dd if=output/imx-boot-sd.bin of=/dev/sdX bs=1K seek=32 && sync
```

### Kernel

When the kernel was build from within the variscite tools it was build with the linaro gcc toolchain.

All commandos are run from within `src/kernel/`:

To use the linaro toolchain set

```
export CROSS_COMPILE=$(pwd)/../toolchain/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-
export ARCH=arm64
```

Due to `var_make_debian.sh` being run with root priviledges due to `sudo` the src folder will not be writeable to normal users.

```
sudo chown $(whoami) -R .
```

This `var_make_debian.sh` script and its linaro toolchain create binaries incompatible with
the e.g. ubuntu cross-gcc. Therefore to build the kernel out-of-tree a cleanup is required after correcting permissions:

```
export CROSS_COMPILE=aarch64-linux-gnu-
export ARCH=arm64
make -j`nproc` distclean
make -j`nproc` imx8_var_meticulous_defconfig
```

In either case, we can now build the kernel, modules and dtbs, optionally using `CC="ccache gcc"`

```
make -j`nproc` Image.gz modules dtbs
```

With the sdcard or image mounted to a known folder installing the kernel is straigh forward:
**Adjust mountpoint and device as needed**. Installing to `../../rootfs` is also fine

```
sudo mount /dev/sdb3 /mnt/
sudo make -j`nproc` INSTALL_MOD_PATH=/mnt modules_install
sudo cp arch/arm64/boot/Image.gz /mnt/boot/Image.gz
sudo cp arch/arm64/boot/dts/freescale/imx8mn-var-som-symphony.dtb /mnt/boot/imx8mn-var-som-symphony.dtb
sudo umount /mnt
```

If the kernels `.config` was not changed it is often enough to only copy the Image.gz. The dtbs can also be
changed individually in most cases without the need to copy the whole kernel and its modules.