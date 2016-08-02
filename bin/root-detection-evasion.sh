#!/bin/bash

set -u

ROOT_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})/.." && pwd)"
ROOT_DIR="${ROOT_DIR%/}"
source ${ROOT_DIR}/utilities.sh

USAGE="Usage: ./root-detection-evasion.sh <android sdk directory> <avd name>"
HELP_TEXT="
OPTIONS
-s, --silent                Silent mode, suppresses all output except result
-h, --help                  Display this help and exit

<android sdk directory>     Android SDK installation directory
<avd name>                  The name of the AVD to launch"

SDK_DIR=""
AVD=""
ADB=""
declare -a EXT_APKS=("DetectionEvader.apk")
declare -a EXT_PKGS=("com.nixu.substraterootdetectionevasion")
declare -a APKS=("RootDetector.apk" "RootChecker.apk" "NordeaCodes.apk" "hidesubinary.apk")
declare -a PKGS=("com.nixu.rootdetection" "com.joeykrim.rootcheck" "com.nordea.mobiletoken" "com.nixu.hideroot")

parse_arguments() {
    local show_help=0
    for ((i = 1; i <= $#; i++)); do
        if [ "${!i}" == "-s" ] || [ "${!i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ "${!i}" == "-h" ] || [ "${!i}" == "--help" ]; then
            show_help=1
        elif [ -z "${SDK_DIR}" ]; then
            SDK_DIR="${!i}"
        elif [ -z "${AVD}" ]; then
            AVD="${!i}"
        else
            std_err "Unknown argument: ${!i}"
            std_err "${USAGE}"
            std_err "See -h for more info"
            println "${SDK_DIR}"
            println "${AVD}"
            exit 1
        fi
    done

    if [ ${show_help} -eq 1 ]; then
        print_help
        exit
    fi

    if [ -z "${SDK_DIR}" ] \
    || [ -z "${AVD}" ]; then
        std_err "${USAGE}"
        std_err "See -h for more info"
        exit 1
    fi

    SDK_DIR=${SDK_DIR%/}
} # parse_arguments()

check_files() {
    if [ ! -d "${SDK_DIR}" ]; then
        std_err "Android SDK directory not found!"
        exit 1
    fi

    ADB="${SDK_DIR}/$(ls ${SDK_DIR})/platform-tools/adb"
    println "Files are ok"
} # parse_argumetns()

start_avd() {
    println "Starting AVD: ${AVD}"
    ${SDK_DIR}/$(ls ${SDK_DIR})/tools/emulator -avd ${AVD} -no-boot-anim -wipe-data -partition-size 2047 &>/dev/null &
} # start_avd()

wait_for_device() {
    write "Waiting..."
    output=""
    while [ "${output}" != "stopped" ]; do
        # getprop appends a \r at the end of the string and that is why 'tr' is used here
        output="$(${ADB} wait-for-device shell getprop init.svc.bootanim | tr -cd '[[:alpha:]]')"
        sleep 2
        write "."
    done
    println "\n"
} # wait_for_device()

install_root() {
    println "ROOTING"

    println "Mounting /system as read-write"
    ${ADB} shell mount -o rw,remount /system

    println "Transfering \'su\' binary"
    ${ADB} push ${ROOT_DIR}/bin/root/su /system/xbin/su
    ${ADB} push ${ROOT_DIR}/bin/root/su /system/xbin/surd

    println "Changing permission"
    ${ADB} shell chmod 06755 /system
    ${ADB} shell chmod 06755 /system/xbin/su
    ${ADB} shell chmod 06755 /system/xbin/surd

    println ""
} # install_root()

install_substrate() {
    println "SUBSTRATE"

    println "Uninstalling old Substrate"
    ${ADB} shell pm uninstall com.saurik.substrate
    println "Installing new Substrate"
    ${ADB} install ${ROOT_DIR}/apks/Substrate.apk
    println "Linking Substrate files"
    ${ADB} shell /data/data/com.saurik.substrate/lib/libSubstrateRun.so do_link
    println "Opening Substrate app"
    ${ADB} shell am start -n com.saurik.substrate/.SetupActivity

    println ""
} # install_substrate()

install_substrate_extensions() {
    println "SUBSTRATE EXTENSIONS\n"

    local app=""
    local package=""
    for i in "${#EXT_APKS[@]}"; do
        app="${EXT_APKS[${i}]}"
        package="${EXT_PKGS[${i}]}"
        println "Uninstalling old apk: ${app}"
        ${ADB} shell pm uninstall ${package}
        println "Installing new apk: ${app}"
        ${ADB} install ${ROOT_DIR}/apks/${app}
    done

    println ""
} # install_substrate_extensions()

install_apks() {
    println "ADDITIONAL APK\'S"
    local app=""
    local package=""
    for i in "${#APKS[@]}"; do
        app="${APKS[${i}]}"
        package="${PKGS[${i}]}"
        println "Uninstalling old apk: ${app}"
        ${ADB} shell pm uninstall ${package}
        println "Installing new apk: ${app}"
        ${ADB} install ${ROOT_DIR}/apks/${app}
    done

    println ""
} # install_apks()

reboot_avd() {
    println "Rebooting Android Virtual Device"
    ${ADB} shell su -c setprop ctl.restart zygote
} # reboot()

parse_arguments $@
check_files
start_avd
wait_for_device
install_root
install_substrate
install_substrate_extensions
install_apks
reboot_avd
wait_for_device
println "Done!"
