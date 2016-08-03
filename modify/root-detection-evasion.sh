#!/bin/bash

set -u

ROOT_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})/.." && pwd)"
ROOT_DIR="${ROOT_DIR%/}"
source ${ROOT_DIR}/emulator-utilities.sh

USAGE="Usage: ./root-detection-evasion.sh <android sdk directory> <avd name> [-c|--clear] [-s|--silent]"
HELP_TEXT="
OPTIONS
-c, --clear                 Wipe user data before booting emulator
-s, --silent                Silent mode, suppresses all output except result
-h, --help                  Display this help and exit

<android sdk directory>     Android SDK installation directory
<avd name>                  The name of the AVD to launch"

ASDK_DIR=""
AVD=""
ADB=""
SILENT_MODE=0

declare -a EXT_APKS=("DetectionEvader.apk")
declare -a EXT_PKGS=("com.nixu.substraterootdetectionevasion")
declare -a APKS=("RootDetector.apk" "RootChecker.apk" "NordeaCodes.apk" "hidesubinary.apk")
declare -a PKGS=("com.nixu.rootdetection" "com.joeykrim.rootcheck" "com.nordea.mobiletoken" "com.nixu.hideroot")

parse_arguments() {
    if [ $# -eq 0 ]; then
        std_err "${USAGE}"
        std_err "See -h for more information"
        exit 1
    fi

    local show_help=0
    for ((i = 1; i <= $#; i++)); do
        if [ "${!i}" == "-h" ] || [ "${!i}" == "--help" ]; then
            show_help=1
        elif [ "${!i}" == "-s" ] || [ "${!i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ "${!i}" == "-c" ] || [ "${!i}" == "--clear" ]; then
            CLEAR_DATA="-wipe-data"
        elif [ -z "${ASDK_DIR}" ]; then
            ASDK_DIR="${!i}"
        elif [ -z "${AVD}" ]; then
            AVD="${!i}"
        else
            std_err "Unknown argument: ${!i}"
            std_err "${USAGE}"
            std_err "See -h for more information"
            exit 1
        fi
    done

    if [ ${show_help} -eq 1 ]; then
        print_help
        exit
    fi

    if [ -z "${ASDK_DIR}" ] \
    || [ -z "${AVD}" ]; then
        std_err "${USAGE}"
        std_err "See -h for more information"
        exit 1
    fi
    
    ASDK_DIR=${ASDK_DIR%/}
} # parse_arguments()

setup() {
    ADB="${ASDK_DIR}/$(ls ${ASDK_DIR})/platform-tools/adb"
} # setup()

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
    for ((i=0; i < ${#EXT_APKS[@]}; i++)); do
        app="${EXT_APKS[${i}]}"
        package="${EXT_PKGS[${i}]}"
        println "Uninstalling old apk: ${app}"
        ${ADB} shell pm uninstall ${package}
        if [ -f "${ROOT_DIR}/apks/${app}" ]; then
            println "Installing new apk: ${app}"
            ${ADB} install ${ROOT_DIR}/apks/${app}
        else
            std_err "Could not find apk: ${app}"
        fi
    done

    println ""
} # install_substrate_extensions()

install_apks() {
    println "ADDITIONAL APK\'S"
    local app=""
    local package=""
    for ((i = 0; i < ${#APKS[@]}; i++)); do
        app="${APKS[${i}]}"
        package="${PKGS[${i}]}"
        println "Uninstalling old apk: ${app}"
        ${ADB} shell pm uninstall ${package}
        if [ -f "${ROOT_DIR}/apks/${app}" ]; then
            println "Installing new apk: ${app}"
            ${ADB} install ${ROOT_DIR}/apks/${app}
        else
            std_err "Could not find apk: ${app}"
        fi
    done

    println ""
} # install_apks()


parse_arguments $@
setup

modifier=""
[ ${SILENT_MODE} -eq 1 ] && modifier="-s"
${ROOT_DIR}/bin/run-emulator.sh ${ASDK_DIR} ${AVD} ${modifier}
[ $? -ne 0 ] && exit 1

printfln ""
install_root
install_substrate
install_substrate_extensions
install_apks
reboot_avd
wait_for_device
println "Done!"
