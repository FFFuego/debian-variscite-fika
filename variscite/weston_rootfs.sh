# Must be called after make_prepare in main script
# generate weston rootfs in input dir
# $1 - rootfs base dir
function make_debian_weston_rootfs()
{
	local ROOTFS_BASE=$1

	pr_info "Make Debian (${DEB_RELEASE}) rootfs start..."

	# umount previus mounts (if fail)
	umount ${ROOTFS_BASE}/{sys,proc,dev/pts,dev} 2>/dev/null || true

	# clear rootfs dir
	rm -rf ${ROOTFS_BASE}/*

	pr_info "rootfs: debootstrap"
	sudo mkdir -p ${ROOTFS_BASE}
	sudo chown -R root:root ${ROOTFS_BASE}
	debootstrap --verbose --no-check-gpg --foreign --arch arm64 ${DEB_RELEASE} \
		${ROOTFS_BASE}/ ${PARAM_DEB_LOCAL_MIRROR}

	# prepare qemu
	pr_info "rootfs: debootstrap in rootfs (second-stage)"
	cp ${G_VARISCITE_PATH}/qemu_64bit/qemu-aarch64-static ${ROOTFS_BASE}/usr/bin/qemu-aarch64-static
	mount -o bind /proc ${ROOTFS_BASE}/proc
	mount -o bind /dev ${ROOTFS_BASE}/dev
	mount -o bind /dev/pts ${ROOTFS_BASE}/dev/pts
	mount -o bind /sys ${ROOTFS_BASE}/sys
	chroot $ROOTFS_BASE /debootstrap/debootstrap --second-stage --verbose

	#Package the base Debian image into a tar.gz file
	pr_info "Packaging the base Debian image"
	if [ -d "${ROOTFS_BASE}" ] && [ "$(ls -A ${ROOTFS_BASE})" ]; then
    	umount ${ROOTFS_BASE}/{sys,proc,dev/pts,dev} 2>/dev/null || true
    	tar czvf ${PARAM_OUTPUT_DIR}/rootfs-base.tar.gz --exclude=sys --exclude=proc --exclude=dev ${ROOTFS_BASE}
	else
    	echo "Error: The directory ${ROOTFS_BASE}  does not exist or is empty."
    	exit 1
	fi
}

function make_variscite_weston_rootfs()
{
	local ROOTFS_BASE=$1
	
	# Unpack the base image to continue with customizations
	pr_info "Unpacking the base Debian image."
	umount ${ROOTFS_BASE}/{sys,proc,dev/pts,dev} 2>/dev/null || true
	tar xzvf ${PARAM_OUTPUT_DIR}/rootfs-base.tar.gz -C ${ROOTFS_BASE}

	mount -o bind /proc ${ROOTFS_BASE}/proc
	mount -o bind /dev ${ROOTFS_BASE}/dev
	mount -o bind /dev/pts ${ROOTFS_BASE}/dev/pts
	mount -o bind /sys ${ROOTFS_BASE}/sys

	# delete unused folder
	chroot $ROOTFS_BASE rm -rf ${ROOTFS_BASE}/debootstrap

	pr_info "rootfs: generate default configs"
	mkdir -p ${ROOTFS_BASE}/etc/sudoers.d/
	echo "user ALL=(root) /usr/bin/apt-get, /usr/bin/dpkg, /usr/bin/vi, /sbin/reboot" > ${ROOTFS_BASE}/etc/sudoers.d/user
	chmod 0440 ${ROOTFS_BASE}/etc/sudoers.d/user
	mkdir -p ${ROOTFS_BASE}/srv/local-apt-repository

	# imx-firmware
	cp -r ${G_VARISCITE_PATH}/deb/imx-firmware-${IMX_FIRMWARE_VERSION}/* \
		${ROOTFS_BASE}/srv/local-apt-repository

	# copy display and gpu packages only if distro feature enabled
	if [ "${G_DEBIAN_DISTRO_FEATURE_GRAPHICS}" = "y" ]; then
		# cairo
		cp -r ${G_VARISCITE_PATH}/deb/cairo/* \
			${ROOTFS_BASE}/srv/local-apt-repository

		# libdrm
		cp -r ${G_VARISCITE_PATH}/deb/libdrm/* \
			${ROOTFS_BASE}/srv/local-apt-repository

		# waylandprotocols
		cp -r ${G_VARISCITE_PATH}/deb/waylandprotocols/* \
			${ROOTFS_BASE}/srv/local-apt-repository

		# weston
		cp -r ${G_VARISCITE_PATH}/deb/weston/${WESTON_PACKAGE_DIR}/* \
			${ROOTFS_BASE}/srv/local-apt-repository

		# G2D_Packages
		if [ ! -z "${G2D_PACKAGE_DIR}" ]; then
			cp -r ${G_VARISCITE_PATH}/deb/${G2D_PACKAGE_DIR}/* \
				${ROOTFS_BASE}/srv/local-apt-repository
		fi

		# Vivante GPU libgbm1 libraries
		if [ ! -z "${G_GPU_IMX_VIV_GBM_DIR}" ]; then
			cp -r ${G_VARISCITE_PATH}/deb/${G_GPU_IMX_VIV_GBM_DIR}/* \
				${ROOTFS_BASE}/srv/local-apt-repository
		fi

		# Vivante GPU libraries
		if [ ! -z "${G_GPU_IMX_VIV_PACKAGE_DIR}" ]; then
			cp -r ${G_VARISCITE_PATH}/deb/${G_GPU_IMX_VIV_PACKAGE_DIR}/* \
				${ROOTFS_BASE}/srv/local-apt-repository
		fi
		# Vivante GPU SDK Binaries
		if [ ! -z "${G_GPU_IMX_VIV_SDK_PACKAGE_DIR}" ]; then
			cp -r ${G_VARISCITE_PATH}/deb/${G_GPU_IMX_VIV_SDK_PACKAGE_DIR}/* \
				${ROOTFS_BASE}/srv/local-apt-repository
		fi
	fi

	# copy gstreamer and multimedia packages only if distro feature enabled
	if [ "${G_DEBIAN_DISTRO_FEATURE_MM}" = "y" ]; then
		# imxcodec
		if [ ! -z "${G_IMX_CODEC_DIR}" ]; then
			cp -r ${G_VARISCITE_PATH}/deb/${G_IMX_CODEC_DIR}/* \
				${ROOTFS_BASE}/srv/local-apt-repository
		fi

		# imxparser
		if [ ! -z "${G_IMX_PARSER_DIR}" ]; then
			cp -r ${G_VARISCITE_PATH}/deb/${G_IMX_PARSER_DIR}/* \
				${ROOTFS_BASE}/srv/local-apt-repository
		fi

		# imxvpuhantro
		if [ ! -z "${G_IMX_VPU_HANTRO_DIR}" ]; then
			cp -r ${G_VARISCITE_PATH}/deb/${G_IMX_VPU_HANTRO_DIR}/* \
				${ROOTFS_BASE}/srv/local-apt-repository
		fi

		# imxvpuhantro-vc
		if [ ! -z "${G_IMX_VPU_HANTRO_VC_DIR}" ]; then
			cp -r ${G_VARISCITE_PATH}/deb/${G_IMX_VPU_HANTRO_VC_DIR}/* \
				${ROOTFS_BASE}/srv/local-apt-repository
		fi

		# imx-vpuwrap
		if [ ! -z "${G_IMX_VPU_WRAPPER_DIR}" ]; then
			cp -r ${G_VARISCITE_PATH}/deb/${G_IMX_VPU_WRAPPER_DIR}/* \
				${ROOTFS_BASE}/srv/local-apt-repository
		fi

		# gstreamer-libav for SW codecs
		if [ ! -z "${G_SW_GST_CODEC_DIR}" ]; then
			cp -r ${G_VARISCITE_PATH}/deb/${G_SW_GST_CODEC_DIR}/* \
				${ROOTFS_BASE}/srv/local-apt-repository
		fi

		# use gstpluginsbad dir if available
		if [ ! -z "${G_GST_PLUGINS_BAD_DIR}" ]; then
			# gstpluginsbad
			cp -r ${G_VARISCITE_PATH}/deb/gstpluginsbad/${G_GST_PLUGINS_BAD_DIR}/* \
				${ROOTFS_BASE}/srv/local-apt-repository
		else
			# gstpluginsbad
			cp -r ${G_VARISCITE_PATH}/deb/gstpluginsbad/${GST_MM_VERSION}/* \
				${ROOTFS_BASE}/srv/local-apt-repository
		fi

		# gstpluginsbase
		cp -r ${G_VARISCITE_PATH}/deb/gstpluginsbase/${GST_MM_VERSION}/* \
			${ROOTFS_BASE}/srv/local-apt-repository

		# gstpluginsgood
		cp -r ${G_VARISCITE_PATH}/deb/gstpluginsgood/${GST_MM_VERSION}/* \
			${ROOTFS_BASE}/srv/local-apt-repository

		# gstreamer
		cp -r ${G_VARISCITE_PATH}/deb/gstreamer/${GST_MM_VERSION}/* \
			${ROOTFS_BASE}/srv/local-apt-repository

		# imxgstplugin
		cp -r ${G_VARISCITE_PATH}/deb/imxgstplugin/${GST_MM_VERSION}/* \
			${ROOTFS_BASE}/srv/local-apt-repository

		# opencv
		if [ ! -z "${G_OPENCV_DIR}" ]; then
			cp -r ${G_VARISCITE_PATH}/deb/${G_OPENCV_DIR}/* \
				${ROOTFS_BASE}/srv/local-apt-repository
		fi
	fi

	# copy machine lerning packages only if distro feature enabled
	if [ "${G_DEBIAN_DISTRO_FEATURE_ML}" = "y" ]; then

		# imx-nn
		if [ ! -z "${G_IMX_NN_DIR}" ]; then
			cp -r ${G_VARISCITE_PATH}/deb/${G_IMX_NN_DIR}/* \
				${ROOTFS_BASE}/srv/local-apt-repository
		fi
	fi

# add mirror to source list
echo "
deb ${DEF_DEBIAN_MIRROR} ${DEB_RELEASE} main contrib non-free
deb-src ${DEF_DEBIAN_MIRROR} ${DEB_RELEASE} main contrib non-free

deb ${DEF_DEBIAN_MIRROR}-security ${DEB_RELEASE}-security main contrib non-free
deb-src ${DEF_DEBIAN_MIRROR}-security ${DEB_RELEASE}-security main contrib non-free

deb ${DEF_DEBIAN_MIRROR} ${DEB_RELEASE}-updates main contrib non-free
deb-src ${DEF_DEBIAN_MIRROR} ${DEB_RELEASE}-updates main contrib non-free

deb ${DEF_DEBIAN_MIRROR} ${DEB_RELEASE}-backports main contrib non-free
deb-src ${DEF_DEBIAN_MIRROR} ${DEB_RELEASE}-backports main contrib non-free
" > etc/apt/sources.list

# maximize local repo priority
echo "Package: *
Pin: origin ""
Pin-Priority: 1000
" > etc/apt/preferences.d/local

# raise backports priority
echo "Package: *
Pin: release n=${DEB_RELEASE}-backports
Pin-Priority: 600
" > etc/apt/preferences.d/backports

# Don't check valid until for snapshot releases
echo "Acquire::Check-Valid-Until no;" > etc/apt/apt.conf.d/99no-check-valid-until

install -m 0644 ${G_VARISCITE_PATH}/fstab etc/fstab

echo "${MACHINE}" > etc/hostname

echo "auto lo
iface lo inet loopback
" > etc/network/interfaces

echo "
locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8
locales locales/default_environment_locale select en_US.UTF-8
console-common	console-data/keymap/policy	select	Select keymap from full list
keyboard-configuration keyboard-configuration/variant select 'English (US)'
openssh-server openssh-server/permit-root-login select true
" > debconf.set

	pr_info "rootfs: prepare install packages in rootfs"
# apt-get install without starting
cat > ${ROOTFS_BASE}/usr/sbin/policy-rc.d << EOF
#!/bin/sh
exit 101
EOF

chmod +x ${ROOTFS_BASE}/usr/sbin/policy-rc.d

# rootfs packages console only stage
cat > rootfs-stage-base << EOF
#!/bin/bash
# apply debconfig options
debconf-set-selections /debconf.set
rm -f /debconf.set

function protected_install()
{
	local _name=\${1}
	local repeated_cnt=5;
	local RET_CODE=1;

	echo Installing \${_name}
	for (( c=0; c<\${repeated_cnt}; c++ ))
	do
		apt install -y \${_name} && {
			RET_CODE=0;
			break;
		};

		echo
		echo "##########################"
		echo "## Fix missing packages ##"
		echo "##########################"
		echo

		sleep 2;

		apt --fix-broken install -y && {
			RET_CODE=0;
			break;
		};
	done

	return \${RET_CODE}
}

# update packages and install base
apt-get update || apt-get upgrade

# local-apt-repository support
protected_install local-apt-repository

# update packages and install base
apt-get update || apt-get upgrade

# update packages and install base
apt-get update

protected_install libc6-dev
protected_install locales
protected_install ntp
protected_install openssh-sftp-server
protected_install openssh-server
protected_install nfs-common

# install packages for rauc
protected_install git
protected_install autoconf
protected_install automake
protected_install libtool
protected_install pkg-config
protected_install libdbus-1-dev
protected_install libglib2.0-dev
protected_install libgio2.0-cil-dev
protected_install libgirepository1.0-dev
protected_install libjson-glib-dev
protected_install libssl-dev
protected_install libcurl4-openssl-dev
protected_install libnl-genl-3-dev
protected_install meson

# packages required when flashing emmc
protected_install dosfstools

# fix config for sshd (permit root login)
sed -i -e 's/#PermitRootLogin.*/PermitRootLogin\tyes/g' /etc/ssh/sshd_config

# net-tools (ifconfig, etc.)
protected_install net-tools
protected_install network-manager

# sdma package
protected_install imx-firmware-sdma

# VPU package
protected_install imx-firmware-vpu

# epdc package
protected_install imx-firmware-epdc

# hdmi firmware package
if [ ! -z "${HDMI_FIRMWARE_PACKAGE}" ]
then
	protected_install ${HDMI_FIRMWARE_PACKAGE}
fi

# xcvr firmware package
if [ ! -z "${XCVR_FIRMWARE_PACKAGE}" ]
then
	protected_install ${XCVR_FIRMWARE_PACKAGE}
fi

# alsa
protected_install alsa-utils

# i2c tools
protected_install i2c-tools

# usb tools
protected_install usbutils

# libgpiod
protected_install gpiod
protected_install libgpiod2
protected_install python3-libgpiod

# net tools
protected_install iperf3

protected_install rng-tools

# mtd
protected_install mtd-utils

# bluetooth
protected_install bluetooth
protected_install bluez-obexd
protected_install bluez-tools
protected_install pulseaudio
protected_install pulseaudio-module-bluetooth

# wifi support packages
protected_install hostapd
protected_install udhcpd

# disable the hostapd service by default
systemctl disable hostapd.service

# can support
protected_install can-utils

# pmount
protected_install pmount

# pm-utils
protected_install pm-utils

# install dpkg-dev for dpkg-buildpackage
protected_install debhelper
protected_install dh-python
protected_install apt-src
if [ "${G_NO_EXECSTACK}" != "y" ]; then
	protected_install execstack
fi

apt-get -y autoremove

#update iptables alternatives to legacy
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

#install usleep busybox applet
ln -sf /bin/busybox /bin/usleep

# create users and set password
useradd -m -G audio -s /bin/bash user
usermod -a -G video user
echo "user:user" | chpasswd
echo "root:root" | chpasswd

# add users to pulse-access group
usermod -a -G pulse-access root
usermod -a -G pulse-access user

# update pulse home directory
usermod -d /var/run/pulse pulse

# sudo kill rootfs-stage-base
rm -f rootfs-stage-base
EOF

# rootfs packages graphics stage
cat > rootfs-stage-graphics << EOF
#!/bin/bash
# apply debconfig options
debconf-set-selections /debconf.set
rm -f /debconf.set

function protected_install()
{
	local _name=\${1}
	local repeated_cnt=5;
	local RET_CODE=1;

	echo Installing \${_name}
	for (( c=0; c<\${repeated_cnt}; c++ ))
	do
		apt install -y \${_name} && {
			RET_CODE=0;
			break;
		};

		echo
		echo "##########################"
		echo "## Fix missing packages ##"
		echo "##########################"
		echo

		sleep 2;

		apt --fix-broken install -y && {
			RET_CODE=0;
			break;
		};
	done

	return \${RET_CODE}
}

# update packages and install base
apt-get update || apt-get upgrade
# graphical packages
protected_install libdrm-vivante1
protected_install libgbm1
protected_install imx-gpu-viv-core
protected_install dpkg-dev
if [ ! -z "${IMX_GPU_VIV_DEFAULT_WL_PACKAGE}" ]
then
	echo "Default Vivante WL package is imx-gpu-viv-core"
else
	protected_install imx-gpu-viv-wl
fi


if [ ! -z "${G2DPACKAGE}" ]
then
	protected_install ${G2DPACKAGE}
fi
protected_install weston


# GPU SDK
if [ ! -z "${G_GPU_IMX_VIV_SDK_PACKAGE_DIR}" ]
then
       protected_install libdevil-dev
       protected_install libwayland-egl-backend-dev
       protected_install glslang-tools
       protected_install libassimp-dev
       protected_install imx-gpu-sdk-console
       protected_install imx-gpu-sdk-gles2
       protected_install imx-gpu-sdk-gles3
       protected_install imx-gpu-sdk-opencl
       protected_install imx-gpu-sdk-window
fi
#sudo kill rootfs-stage-graphics
rm -f rootfs-stage-graphics
EOF

# rootfs packages multimedia stage
cat > rootfs-stage-gstreamer << EOF
#!/bin/bash
# apply debconfig options
debconf-set-selections /debconf.set
rm -f /debconf.set

function protected_install()
{
	local _name=\${1}
	local repeated_cnt=5;
	local RET_CODE=1;

	echo Installing \${_name}
	for (( c=0; c<\${repeated_cnt}; c++ ))
	do
		apt install -y \${_name} && {
			RET_CODE=0;
			break;
		};

		echo
		echo "##########################"
		echo "## Fix missing packages ##"
		echo "##########################"
		echo

		sleep 2;

		apt --fix-broken install -y && {
			RET_CODE=0;
			break;
		};
	done

	return \${RET_CODE}
}

# update packages and install base
apt-get update || apt-get upgrade

# gstreamer
protected_install gstreamer1.0-plugins-bad
protected_install gstreamer1.0-plugins-base
protected_install gstreamer1.0-plugins-base-apps
protected_install gstreamer1.0-plugins-good
protected_install gstreamer1.0-tools
protected_install ${IMXGSTPLG}

# install SW encoders/decoders for socs that lacks HW based
# encoders/decoders
if [ ! -z "${G_GST_EXTRA_PLUGINS}" ]
then
	protected_install ${G_GST_EXTRA_PLUGINS}
fi

if [ ! -z "${G_SW_ENCODER_DECODERS}" ]
then
	protected_install ${G_SW_ENCODER_DECODERS}
fi

# sudo kill rootfs-stage-gstreamer
rm -f rootfs-stage-gstreamer
EOF

# rootfs packages machine learning stage
cat > rootfs-stage-ml << EOF
#!/bin/bash
# apply debconfig options
debconf-set-selections /debconf.set
rm -f /debconf.set

function protected_install()
{
	local _name=\${1}
	local repeated_cnt=5;
	local RET_CODE=1;

	echo Installing \${_name}
	for (( c=0; c<\${repeated_cnt}; c++ ))
	do
		apt install -y \${_name} && {
			RET_CODE=0;
			break;
		};

		echo
		echo "##########################"
		echo "## Fix missing packages ##"
		echo "##########################"
		echo

		sleep 2;

		apt --fix-broken install -y && {
			RET_CODE=0;
			break;
		};
	done

	return \${RET_CODE}
}

# update packages and install base
apt-get update || apt-get upgrade

# machine learning packages
protected_install imx-nn

# sudo kill rootfs-stage-ml
rm -f rootfs-stage-ml
EOF

	pr_info "rootfs: install selected Debian packages (console-only-stage)"
	chmod +x rootfs-stage-base
	chroot ${ROOTFS_BASE} /rootfs-stage-base

	if [ "${G_DEBIAN_DISTRO_FEATURE_GRAPHICS}" = "y" ]; then
		pr_info "rootfs: install selected Debian packages (Graphics - GPU/Weston)"
		chmod +x rootfs-stage-graphics
		chroot ${ROOTFS_BASE} /rootfs-stage-graphics
	else
		rm -f ${ROOTFS_BASE}/rootfs-stage-graphics
	fi

	if [ "${G_DEBIAN_DISTRO_FEATURE_MM}" = "y" ]; then
		pr_info "rootfs: install selected Debian packages (MM Gstreamer)"
		chmod +x rootfs-stage-gstreamer
		chroot ${ROOTFS_BASE} /rootfs-stage-gstreamer
	else
		rm -f ${ROOTFS_BASE}/rootfs-stage-gstreamer
	fi

	if [ "${G_DEBIAN_DISTRO_FEATURE_ML}" = "y" ]; then
		pr_info "rootfs: install selected Debian packages (Machine Learning)"
		chmod +x rootfs-stage-ml
		chroot ${ROOTFS_BASE} /rootfs-stage-ml
	else
		rm -f ${ROOTFS_BASE}/rootfs-stage-ml
	fi

	# install variscite-bt service
	install -m 0755 ${G_VARISCITE_PATH}/brcm_patchram_plus \
		${ROOTFS_BASE}/usr/bin
	install -d ${ROOTFS_BASE}/etc/bluetooth
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/variscite-bt.conf \
		${ROOTFS_BASE}/etc/bluetooth
	install -m 0755 ${G_VARISCITE_PATH}/variscite-bt \
		${ROOTFS_BASE}/etc/bluetooth
	install -m 0755 ${G_VARISCITE_PATH}/variscite-bt-common.sh \
		${ROOTFS_BASE}/etc/bluetooth
	install -m 0644 ${G_VARISCITE_PATH}/variscite-bt.service \
		${ROOTFS_BASE}/lib/systemd/system
	ln -s /lib/systemd/system/variscite-bt.service \
		${ROOTFS_BASE}/etc/systemd/system/multi-user.target.wants/variscite-bt.service

	# install BT audio and main config
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/bluez5/files/audio.conf \
		${ROOTFS_BASE}/etc/bluetooth/
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/bluez5/files/main.conf \
		${ROOTFS_BASE}/etc/bluetooth/

	# install obexd configuration
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/bluez5/files/obexd.conf \
		${ROOTFS_BASE}/etc/dbus-1/system.d

	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/bluez5/files/obex.service \
		${ROOTFS_BASE}/lib/systemd/system
	ln -s /lib/systemd/system/obex.service \
		${ROOTFS_BASE}/etc/systemd/system/multi-user.target.wants/obex.service

	# install pulse audio configuration
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/pulseaudio/pulseaudio.service \
		${ROOTFS_BASE}/lib/systemd/system
	ln -s /lib/systemd/system/pulseaudio.service \
		${ROOTFS_BASE}/etc/systemd/system/multi-user.target.wants/pulseaudio.service
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/pulseaudio/pulseaudio-bluetooth.conf \
		${ROOTFS_BASE}/etc//dbus-1/system.d
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/pulseaudio/system.pa \
		${ROOTFS_BASE}/etc/pulse/
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/pulseaudio/client.conf \
		${ROOTFS_BASE}/etc/pulse/

	# install alsa-libs and alisas files
	if [ ! -z "${ALSA_CONF_FILES_DIR}" ]; then
		install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/${ALSA_CONF_FILES_DIR}/IMX-HDMI.conf \
			${ROOTFS_BASE}/usr/share/alsa/cards/
		install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/${ALSA_CONF_FILES_DIR}/IMX-XCVR.conf \
			${ROOTFS_BASE}/usr/share/alsa/cards/
		install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/${ALSA_CONF_FILES_DIR}/CS42888.conf \
			${ROOTFS_BASE}/usr/share/alsa/cards/
		install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/${ALSA_CONF_FILES_DIR}/AK4458.conf \
			${ROOTFS_BASE}/usr/share/alsa/cards/
		install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/${ALSA_CONF_FILES_DIR}/aliases.conf \
			${ROOTFS_BASE}/usr/share/alsa/cards/
	fi

	rm -rf ${ROOTFS_BASE}/etc/systemd/user/sockets.target.wants/pulseaudio.socket
	rm -rf ${ROOTFS_BASE}/etc/systemd/user/default.target.wants/pulseaudio.service
	
	rm -f ${ROOTFS_BASE}/etc/xdg/autostart/pulseaudio.desktop

	# install blacklist.conf
	install -d ${ROOTFS_BASE}/etc/modprobe.d/
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/blacklist.conf \
		${ROOTFS_BASE}/etc/modprobe.d/

	# install variscite-wifi service
	install -d ${ROOTFS_BASE}/etc/wifi
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/variscite-wifi.conf \
		${ROOTFS_BASE}/etc/wifi
	install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/variscite-wifi-common.sh \
		${ROOTFS_BASE}/etc/wifi
	install -m 0755 ${G_VARISCITE_PATH}/variscite-wifi \
		${ROOTFS_BASE}/etc/wifi
	install -m 0644 ${G_VARISCITE_PATH}/variscite-wifi.service \
		${ROOTFS_BASE}/lib/systemd/system
	ln -s /lib/systemd/system/variscite-wifi.service \
		${ROOTFS_BASE}/etc/systemd/system/multi-user.target.wants/variscite-wifi.service

	#install securetty
	install -m 0644 ${G_VARISCITE_PATH}/securetty \
		${ROOTFS_BASE}/etc/securetty

	if [ "${G_DEBIAN_DISTRO_FEATURE_GRAPHICS}" = "y" ]; then
		# install weston service
		install -d ${ROOTFS_BASE}/etc/xdg/weston
		install -m 0644 ${G_VARISCITE_PATH}/${MACHINE}/weston.ini \
			${ROOTFS_BASE}/etc/xdg/weston
		install -m 0755 ${G_VARISCITE_PATH}/${MACHINE}/weston.config \
			${ROOTFS_BASE}/etc/default/weston
		install -m 0755 ${G_VARISCITE_PATH}/weston-start \
			${ROOTFS_BASE}/usr/bin/weston-start
		install -m 0755 ${G_VARISCITE_PATH}/weston.profile \
			${ROOTFS_BASE}/etc/profile.d/weston.sh
		install -m 0644 ${G_VARISCITE_PATH}/weston.service \
			${ROOTFS_BASE}/lib/systemd/system
		ln -s /lib/systemd/system/weston.service \
			${ROOTFS_BASE}/etc/systemd/system/multi-user.target.wants/weston.service
	fi

	# remove pm-utils default scripts and install wifi / bt pm-utils script
	rm -rf ${ROOTFS_BASE}/usr/lib/pm-utils/sleep.d/
	rm -rf ${ROOTFS_BASE}/usr/lib/pm-utils/module.d/
	rm -rf ${ROOTFS_BASE}/usr/lib/pm-utils/power.d/
	install -m 0755 ${G_VARISCITE_PATH}/${MACHINE}/01-bt.sh \
		${ROOTFS_BASE}/etc/pm/sleep.d/
	install -m 0755 ${G_VARISCITE_PATH}/${MACHINE}/02-wifi.sh \
		${ROOTFS_BASE}/etc/pm/sleep.d/
	if [ -f ${G_VARISCITE_PATH}/${MACHINE}/00-eth.sh ]; then
		install -m 0755 ${G_VARISCITE_PATH}/${MACHINE}/00-eth.sh \
			${ROOTFS_BASE}/etc/pm/sleep.d/
	fi
	if [ -f ${G_VARISCITE_PATH}/${MACHINE}/03-eth.sh ]; then
		install -m 0755 ${G_VARISCITE_PATH}/${MACHINE}/03-eth.sh \
			${ROOTFS_BASE}/etc/pm/sleep.d/
	fi
	if [ -f ${G_VARISCITE_PATH}/${MACHINE}/04-usb.sh ]; then
		install -m 0755 ${G_VARISCITE_PATH}/${MACHINE}/04-usb.sh \
			${ROOTFS_BASE}/etc/pm/sleep.d/
	fi

	# we don't want systemd to handle the power key
	echo "HandlePowerKey=ignore" >> ${ROOTFS_BASE}/etc/systemd/logind.conf

	#Build kernel headers on the target
	pr_info "rootfs: Building kernel-headers"
	cp -ar ${PARAM_OUTPUT_DIR}/kernel-headers ${ROOTFS_BASE}/tmp/

	echo "#!/bin/bash
	# update packages
	cd /tmp/kernel-headers
	dpkg-buildpackage -b -j4 -us -uc
	cp -ar /tmp/*.deb /srv/local-apt-repository/
	dpkg-reconfigure local-apt-repository
	cd -
	rm -rf /var/cache/apt/*
	rm -f header-stage
	" > header-stage

	chmod +x header-stage
	chroot ${ROOTFS_BASE} /header-stage

	# binaries rootfs patching
	install -m 0644 ${G_VARISCITE_PATH}/issue ${ROOTFS_BASE}/etc/
	install -m 0644 ${G_VARISCITE_PATH}/issue.net ${ROOTFS_BASE}/etc/
	install -m 0755 ${G_VARISCITE_PATH}/rc.local ${ROOTFS_BASE}/etc/
	install -d ${ROOTFS_BASE}/boot/
	cp ${PARAM_OUTPUT_DIR}/Image.gz ${ROOTFS_BASE}/boot
	cp ${PARAM_OUTPUT_DIR}/*.dtb ${ROOTFS_BASE}/boot
	if [ "$DEFAULT_BOOT_DTB" != "$BOOT_DTB" ]; then
		ln -sf ${DEFAULT_BOOT_DTB} ${ROOTFS_BASE}/boot/${BOOT_DTB}
		if [ ! -z "${BOOT_DTB2}" ]; then
			ln -sf ${DEFAULT_BOOT_DTB2} \
				${ROOTFS_BASE}/boot/${BOOT_DTB2}
		fi
	fi

	mkdir -p ${ROOTFS_BASE}/usr/share/images/desktop-base/
	install -m 0644 ${G_VARISCITE_PATH}/wallpaper_hd.png \
		${ROOTFS_BASE}/usr/share/images/desktop-base/default

	# Add alsa default configs
	install -m 0644 ${G_VARISCITE_PATH}/asound.state \
		${ROOTFS_BASE}/var/lib/alsa/
	install -m 0644 ${G_VARISCITE_PATH}/asound.conf ${ROOTFS_BASE}/etc/

	# Revert regular booting
	rm -f ${ROOTFS_BASE}/usr/sbin/policy-rc.d

	# install kernel modules in rootfs
	install_kernel_modules \
		${G_CROSS_COMPILER_PATH}/${G_CROSS_COMPILER_PREFIX} \
		${G_LINUX_KERNEL_DEF_CONFIG} ${G_LINUX_KERNEL_SRC_DIR} \
		${ROOTFS_BASE}

	# copy all kernel headers for development
	mkdir -p ${ROOTFS_BASE}/usr/local/src/linux-imx/drivers/staging/android/uapi
	cp ${G_LINUX_KERNEL_SRC_DIR}/drivers/staging/android/uapi/* \
	${ROOTFS_BASE}/usr/local/src/linux-imx/drivers/staging/android/uapi
	cp -r ${G_LINUX_KERNEL_SRC_DIR}/include \
		${ROOTFS_BASE}/usr/local/src/linux-imx/

	# copy custom files
	cp ${G_VARISCITE_PATH}/${MACHINE}/fw_env.config ${ROOTFS_BASE}/etc
	cp ${PARAM_OUTPUT_DIR}/fw_printenv ${ROOTFS_BASE}/usr/bin
	ln -sf fw_printenv ${ROOTFS_BASE}/usr/bin/fw_setenv
	cp ${G_VARISCITE_PATH}/10-imx.rules ${ROOTFS_BASE}/etc/udev/rules.d
	cp ${G_VARISCITE_PATH}/automount.rules ${ROOTFS_BASE}/etc/udev/rules.d

	umount ${ROOTFS_BASE}/{sys,proc,dev/pts,dev} 2>/dev/null || true
}
