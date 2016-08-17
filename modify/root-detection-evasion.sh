#!/bin/bash

set -u

ROOT_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})/.." && pwd)"
ROOT_DIR="${ROOT_DIR%/}"
LOG_DIR="${ROOT_DIR}/logs"
LOG_FILE="AET.log"
source ${ROOT_DIR}/emulator-utilities.sh

USAGE="Usage: ./root-detection-evasion.sh <configuration file> [-c|--clear] [-s|--silent]"
HELP_TEXT="
OPTIONS
-c, --clear                 Wipe user data before booting emulator
-d, --debug                 Debug mode, command output is logged to logs/AET.log
-s, --silent                Silent mode, suppresses all output except result
-h, --help                  Display this help and exit

<configuration file>        Configuration file for root detection evasion script"

SILENT_MODE=0
DEBUG_MODE=0
CONF_FILE=""
ASDK_DIR=""
AVD=""
ADB=""

WHITESPACE_REGEX="^[[:blank:]]*$"
COMMENT_REGEX="^[[:blank:]]*\#"
SDK_REGEX="^sdk_dir[[:blank:]]*=[[:blank:]]*\(.*\)"
AVD_REGEX="^avd_name[[:blank:]]*=[[:blank:]]*\(.*\)"
APKS_REGEX="^apks[[:blank:]]*=[[:blank:]]*\(.*\)"
PACKAGES_REGEX="^packages[[:blank:]]*=[[:blank:]]*\(.*\)"
EXTENSION_APKS_REGEX="^extension_apks[[:blank:]]*=[[:blank:]]*\(.*\)"
EXTENSION_PACKAGES_REGEX="^extension_packages[[:blank:]]*=[[:blank:]]*\(.*\)"

declare -a APKS=()
declare -a PKGS=()
declare -a EXTENSION_APKS=()
declare -a EXTENSION_PKGS=()

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
        elif [ "${!i}" == "-d" ] || [ "${!i}" == "--debug" ]; then
            DEBUG_MODE=1
        elif [ "${!i}" == "-c" ] || [ "${!i}" == "--clear" ]; then
            CLEAR_DATA="-wipe-data"
        elif [ -z "${CONF_FILE}" ]; then
            CONF_FILE="${!i}"
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

    if [ -z "${CONF_FILE}" ]; then
        std_err "${USAGE}"
        std_err "See -h for more information"
        exit 1
    fi

    if [ ! -f ${CONF_FILE} ]; then
        std_err "Cannot find configuration file: ${CONF_FILE}"
        exit 1
    fi
} # parse_arguments()

read_conf() {
    while read line; do
        local IFS=$'\t, '

        if [ $(expr "${line}" : "${WHITESPACE_REGEX}") -gt 0 ]; then
            continue
        elif [ $(expr "${line}" : "${COMMENT_REGEX}") -gt 0 ]; then
            continue
        elif [ -z "${line}" ]; then
            continue
        fi

        local sdk_dir_capture=$(expr "${line}" : "${SDK_REGEX}")
        local avd_capture=$(expr "${line}" : "${AVD_REGEX}")
        local apks_capture=$(expr "${line}" : "${APKS_REGEX}")
        local packages_capture=$(expr "${line}" : "${PACKAGES_REGEX}")
        local extension_apks_capture=$(expr "${line}" : "${EXTENSION_APKS_REGEX}")
        local extension_packages_capture=$(expr "${line}" : "${EXTENSION_PACKAGES_REGEX}")

        if [ ! -z "${sdk_dir_capture}" ]; then
            ASDK_DIR="${sdk_dir_capture/\~/${HOME}}"
        elif [ ! -z "${avd_capture}" ]; then
            AVD="${avd_capture}"
        elif [ ! -z "${apks_capture}" ]; then
            read -r -a APKS <<< "${apks_capture}"
        elif [ ! -z "${packages_capture}" ]; then
            read -r -a PKGS <<< "${packages_capture}"
        elif [ ! -z "${extension_apks_capture}" ]; then
            read -r -a EXTENSION_APKS <<< "${extension_apks_capture}"
        elif [ ! -z "${extension_packages_capture}" ]; then
            read -r -a EXTENSION_PKGS <<< "${extension_packages_capture}"
        fi
    done < "${CONF_FILE}"

    if [ -z "${ASDK_DIR}" ]; then
        std_err "Android SDK directory has not been specified!"
        exit 1
    fi

    if [ -z "${AVD}" ]; then
        std_err "Android Virtual Device has not been specified!"
        exit 1
    fi

    if [ ${#APKS[@]} -ne ${#PKGS[@]} ]; then
        std_err "APK-package mismatch in the additional apks! Check that you have specified a package for all the apks."
        exit 1
    fi

    if [ ${#EXTENSION_APKS[@]} -ne ${#EXTENSION_PKGS[@]} ]; then
        std_err ${#EXTENSION_APKS[@]}
        std_err ${#EXTENSION_PKGS[@]}
        std_err "APK-package mismatch in the Substrate extension apks! Check that you have specified a package for all the apks."
        exit 1
    fi
} # read_conf()

setup() {
    if [ ! -d "${ASDK_DIR}" ]; then
        std_err "Android SDK directory does not exist!"
        exit 1
    fi

    ASDK_DIR="${ASDK_DIR%/}"

    println "Adding adb to PATH (this shell only)"
    export PATH=${PATH}:${ASDK_DIR}/$(ls ${ASDK_DIR})/platform-tools/
} # setup()

install_root() {
    println "ROOTING"

    println "Mounting /system as read-write"
    adb shell mount -o rw,remount /system

    println "Transfering \'su\' binary"
    adb push ${ROOT_DIR}/bin/root/su /system/xbin/su
    adb push ${ROOT_DIR}/bin/root/su /system/xbin/surd

    println "Changing permission"
    adb shell chmod 06755 /system
    adb shell chmod 06755 /system/xbin/su
    adb shell chmod 06755 /system/xbin/surd

    println ""
} # install_root()

install_substrate() {
    println "SUBSTRATE"

    println "Uninstalling old Substrate"
    adb shell pm uninstall com.saurik.substrate
    println "Installing new Substrate"
    adb install ${ROOT_DIR}/apks/Substrate.apk
    println "Linking Substrate files"
    adb shell /data/data/com.saurik.substrate/lib/libSubstrateRun.so do_link
    println "Opening Substrate app"
    adb shell am start -n com.saurik.substrate/.SetupActivity

    println ""
} # install_substrate()

install_substrate_extensions() {
    println "SUBSTRATE EXTENSIONS\n"

    local app=""
    local package=""
    for (( i = 0; i < ${#EXTENSION_APKS[@]}; i++ )); do
        app="${EXTENSION_APKS[${i}]}"
        package="${EXTENSION_PKGS[${i}]}"
        println "Uninstalling old apk: ${app}"
        adb shell pm uninstall ${package}
        if [ -f "${ROOT_DIR}/apks/${app}" ]; then
            println "Installing new apk: ${app}"
            adb install ${ROOT_DIR}/apks/${app}
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
    for (( i = 0; i < ${#APKS[@]}; i++ )); do
        app="${APKS[${i}]}"
        package="${PKGS[${i}]}"
        println "Uninstalling old apk: ${app}"
        adb shell pm uninstall ${package}
        if [ -f "${ROOT_DIR}/apks/${app}" ]; then
            println "Installing new apk: ${app}"
            adb install ${ROOT_DIR}/apks/${app}
        else
            std_err "Could not find apk: ${app}"
        fi
    done

    println ""
} # install_apks()


parse_arguments $@
read_conf
setup

modifier=""
[ ${SILENT_MODE} -eq 1 ] && modifier="-s"
emulator_is_running || ${ROOT_DIR}/bin/run-emulator.sh ${ASDK_DIR} ${AVD} ${modifier}
[ $? -ne 0 ] && exit 1

printfln ""
install_root
install_substrate
install_substrate_extensions
install_apks
reboot_avd
wait_for_device
println "Done!"
