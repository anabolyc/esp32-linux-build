#! /bin/bash -x

CTNG_CONFIG=xtensa-esp32s3-linux-uclibcfdpic
BUILDROOT_CONFIG=esp32s3_defconfig
ESP_HOSTED_CONFIG=sdkconfig.defaults.esp32s3

#
# dynconfig
#
if [ ! -f xtensa-dynconfig/esp32s3.so ] ; then
	make -C xtensa-dynconfig ORIG=1 CONF_DIR=`pwd` esp32s3.so
fi
export XTENSA_GNU_CONFIG=`pwd`/xtensa-dynconfig/esp32s3.so

#
# toolchain
#
if [ ! -x crosstool-NG/builds/xtensa-esp32s3-linux-uclibcfdpic/bin/xtensa-esp32s3-linux-uclibcfdpic-gcc ] ; then
	pushd crosstool-NG
	./bootstrap && ./configure --enable-local && make
	./ct-ng $CTNG_CONFIG
	CT_PREFIX=`pwd`/builds ./ct-ng build --quiet
	popd
	[ -x crosstool-NG/builds/xtensa-esp32s3-linux-uclibcfdpic/bin/xtensa-esp32s3-linux-uclibcfdpic-gcc ] || exit 1
fi

#
# kernel and rootfs
#
if [ ! -d build-buildroot-esp32s3 ] ; then
	make -C buildroot O=`pwd`/build-buildroot-esp32s3 $BUILDROOT_CONFIG
	buildroot/utils/config --file build-buildroot-esp32s3/.config --set-str TOOLCHAIN_EXTERNAL_PATH `pwd`/crosstool-NG/builds/xtensa-esp32s3-linux-uclibcfdpic
	buildroot/utils/config --file build-buildroot-esp32s3/.config --set-str TOOLCHAIN_EXTERNAL_PREFIX '$(ARCH)-esp32s3-linux-uclibcfdpic'
	buildroot/utils/config --file build-buildroot-esp32s3/.config --set-str TOOLCHAIN_EXTERNAL_CUSTOM_PREFIX '$(ARCH)-esp32s3-linux-uclibcfdpic'
fi
make -C buildroot O=`pwd`/build-buildroot-esp32s3
[ -f build-buildroot-esp32s3/images/xipImage -a -f build-buildroot-esp32s3/images/rootfs.cramfs -a -f build-buildroot-esp32s3/images/etc.jffs2 ] || exit 1

#
# bootloader
#
pushd esp-hosted/esp_hosted_ng/esp/esp_driver
if [ ! -f ./network_adapter/build/network_adapter.bin ] || [ ! -f ./network_adapter/build/partition_table/partition-table.bin ] || [ ! -f ./network_adapter/build/bootloader/bootloader.bin ] ; then
	cmake .
	alias python='python3'
	cd esp-idf
	. export.sh
	cd ../network_adapter
	idf.py set-target esp32s3
	cp $ESP_HOSTED_CONFIG sdkconfig
	idf.py build
fi
popd

#
# publish artifacts
#
cp -v esp-hosted/esp_hosted_ng/esp/esp_driver/network_adapter/build/bootloader/bootloader.bin ./output 
cp -v esp-hosted/esp_hosted_ng/esp/esp_driver/network_adapter/build/partition_table/partition-table.bin ./output
cp -v esp-hosted/esp_hosted_ng/esp/esp_driver/network_adapter/build/network_adapter.bin ./output

cp -rv build-buildroot-esp32s3/images/* ./output