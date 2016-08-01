#!/bin/bash

ROOT_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})/.." && pwd)"
ROOT_DIR="${EXEC_DIR%/}"
APK_DIR="/home/daniel/Documents/git/android-emulation-environment-setup/apks"
SDK_DIR="/home/daniel/Downloads/sdk/android-sdk-linux"
AVD="TestName"
ADB="${SDK_DIR}/platform-tools/adb"
declare -a EXT_APKS=("DetectionEvader.apk")
declare -a EXT_PKGS=("com.nixu.substraterootdetectionevasion")
declare -a APKS=("RootDetector.apk" "RootChecker.apk" "NordeaCodes.apk" "hidesubinary.apk")
declare -a PKGS=("com.nixu.rootdetection" "com.joeykrim.rootcheck" "com.nordea.mobiletoken" "com.nixu.hideroot")

check_files() {
    if [ ! -d "${APK_DIR}" ]; then
        printf "APK directory not found!\n"
        exit 1
    fi

    if [ ! -d "${SDK_DIR}" ]; then
        printf "Android SDK directory not found!\n"
        exit 1
    fi

    printf "Files are ok\n"
} # parse_argumetns()

start_avd() {
	printf "Starting AVD: ${AVD}\n"
	${SDK_DIR}/tools/emulator -avd ${AVD} -no-boot-anim -wipe-data -partition-size 2047 & &>/dev/null
} # start_avd()

wait_for_device() {
	printf "Waiting...\n"
	output=""
	while [ "${output}" != "stopped" ]; do
		output="$(${ADB} wait-for-device shell getprop init.svc.bootanim | tr -cd '[[:alpha:]]')"
		sleep 2
	done
	printf "\n"
} # wait_for_device()

install_root() {
	printf "ROOTING\n"

	printf "Mounting /system as read-write\n"
	${ADB} shell mount -o rw,remount /system

	printf "Transfering \'su\' binary\n"
	${ADB} push ${ROOT_DIR}/bin/root/su /system/xbin/su
	${ADB} push ${ROOT_DIR}/bin/root/su /system/xbin/surd

	printf "Changing permission\n"
	${ADB} shell chmod 06755 /system
	${ADB} shell chmod 06755 /system/xbin/su
	${ADB} shell chmod 06755 /system/xbin/surd

	printf "\n"
} # install_root()

install_substrate() {
	printf "SUBSTRATE\n"

	printf "Uninstalling old Substrate\n"
	${ADB} shell pm uninstall com.saurik.substrate
	printf "Installing new Substrate\n"
	${ADB} install ${ROOT_DIR}/apks/Substrate.apk
	printf "Linking Substrate files\n"
	${ADB} shell /data/data/com.saurik.substrate/lib/libSubstrateRun.so do_link
	printf "Opening Substrate app\n"
	${ADB} shell am start -n com.saurik.substrate/.SetupActivity

	printf "\n"
} # install_substrate()

install_substrate_extensions() {
	printf "SUBSTRATE EXTENSIONS\n"

	local app=""
	local package=""
	for i in "${#EXTS[@]}"; do
		app="${EXT_APKS[${i}]}"
		package="${EXT_PKGS[${i}]}"
		printf "Uninstalling old apk: ${app}\n"
		${ADB} shell pm uninstall ${package}
		printf "Installing new apk: ${app}\n"
		${ADB} install ${ROOT_DIR}/apks/${app}
	done

	printf "\n"
} # install_substrate_extensions()

install_apks() {
	printf "ADDITIONAL APK'S\n"
	local app=""
	local package=""
	for i in "${#APKS[@]}"; do
		app="${APKS[${i}]}"
		package="${PKGS[${i}]}"
		printf "Uninstalling old apk: ${app}\n"
		${ADB} shell pm uninstall ${package}
		printf "Installing new apk: ${app}\n"
		${ADB} install ${ROOT_DIR}/apks/${app}
	done

	printf "\n"
} # install_apks()

reboot_avd() {
	printf "Rebooting Android Virtual Device\n"
	${ADB} shell su -c setprop ctl.restart zygote
} # reboot()

check_files
start_avd
wait_for_device
install_root
install_substrate
install_substrate_extensions
install_apks
reboot_avd
