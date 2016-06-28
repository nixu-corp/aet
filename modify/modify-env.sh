#!/bin/bash

set -u

EXEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXEC_DIR=${EXEC_DIR%/}
ROOT_DIR="$(cd "${EXEC_DIR}/.." && pwd)"
source ${ROOT_DIR}/utilities.sh

USAGE="Usage: ./modify-env.sh [-s|--silent] [-r sudo password] <configuration file>"
HELP_TEXT="
OPTIONS
-r, --root              By giving root privileges the script can utilize all
                        functitonalities
-s, --silent            Silent mode, suppresses all output except result
-h, --help              Display this help and exit

<configuration file>    Configuration file for modify-env script"
HELP_MSG="${USAGE}\n${HELP_TEXT}"

BANNER="
========================================
>                                      <
>    Environment modification script   <
>       Author: Daniel Riissanen       <
>                                      <
========================================
"

CONF_FILE=""
SYS_IMG_FILE=""
SUDO_PASSWORD=""

WHITESPACE_REGEX="^[[:blank:]]*$"
COMMENT_REGEX="^[[:blank:]]*#"
SYS_IMG_REGEX="^system_img_dir_file[[:blank:]]*=[[:blank:]]*\(.*\)"

TMP_RAMDISK_DIR="ramdisk"
TMP_MOUNT_DIR="mount"
SYS_IMG_DIR=""
MKBOOTFS_FILE="mkbootfs"
SYSTEM_FILE="system.img"
RAMDISK_FILE="ramdisk.img"
DEFAULT_PROP_FILE="default.prop"

BUILD_PROP_FILE="build.prop"

SUCCESSES=0

declare -a SYS_IMG_DIRS=()
declare -A default_prop_changes
declare -A build_prop_changes

#######################
# General functions
#######################
abort() {
    std_err ""
    std_err "ABORTING..."
    std_err "Cleanup"
    cleanup
    std_err "\033[0;31mFailure!\033[0m"
    exit
} # abort()

check_option_value() {
    local index="${1}"
    index=$((index + 1))

    if [ ${index} -gt $(($#)) ] \
    || [ $(expr "${!index}" : "^-.*$") -gt 0 ] \
    || [ $(expr "${!index}" : "^$") -gt 0 ]; then
        return 1
    else
        return 0
    fi
} # check_option_value()

setup() {
    default_prop_changes["ro.secure"]="1"
    default_prop_changes["ro.bootimage.build.fingerprint"]="fingerprint"

    build_prop_changes["ro.build.host"]="host"
    build_prop_changes["ro.build.fingerprint"]="fingerprint"
    build_prop_changes["ro.build.product"]="product"
    build_prop_changes["ro.product.name"]="name"
    build_prop_changes["ro.product.manufacturer"]="known"
    build_prop_changes["ro.product.brand"]="Android"
    build_prop_changes["ro.product.device"]="device"
    build_prop_changes["ro.product.model"]="model"
} # setup()

parse_arguments() {
    local show_help=0
    for ((i = 1; i <= $#; i++)); do
        if [ "${!i}" == "-r" ] || [ "${!i}" == "--root" ]; then
            i=$((i + 1))
            check_option_value ${i} $@
            if [ $? -eq 1 ]; then
                std_err "No sudo password given!\n"
                std_err "${USAGE}"
                std_err "See -h for more info"
                exit 1
            else
                SUDO_PASSWORD="${!i}"
            fi
        elif [ "${!i}" == "-s" ] || [ "${!i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ "${!i}" == "-h" ] || [ "${!i}" == "--help" ]; then
            show_help=1
        elif [ -z "${CONF_FILE}" ]; then
            CONF_FILE="${!i}"
        else
            std_err "Unknown argument: ${!i}"
            std_err "${USAGE}"
            std_err "See -h for more info"
            exit 1
        fi
    done

    if [ ${show_help} -eq 1 ]; then
        print_help
        exit
    fi

    if [ -z "${CONF_FILE}" ]; then
        println "${USAGE}"
        println "See -h for more info"
        exit 1
    fi

    if [ ! -f ${CONF_FILE} ]; then
        std_err "Configuration file does not exist!"
        abort
    fi
} # parse_arguments()

read_conf() {
    while read line; do
        if [ $(expr "${line}" : "${COMMENT_REGEX}") -gt 0 ]; then
            continue
        elif [ $(expr "${line}" : "${WHITESPACE_REGEX}") -gt 0 ]; then
            continue
        elif [ -z "${line}" ]; then
            continue
        fi

        local sys_img_dir_file_capture=$(expr "${line}" : "${SYS_IMG_REGEX}")
        if [ ! -z "${sys_img_dir_file_capture}" ]; then
            SYS_IMG_FILE="${sys_img_dir_file_capture}"
            SYS_IMG_FILE="${SYS_IMG_FILE%/}"
        else
            std_err "Unknown configuration found: ${line}"
            abort
        fi
    done < "${CONF_FILE}"
} # read_conf()

read_sys_img_file() {
    if [ ! -f ${SYS_IMG_FILE} ]; then
        std_err "System image directory file cannot be found!"
        std_err "Please verify the path in the configuration file"
        exit 1
    fi

    while read line; do
        if [ $(expr "${line}" : "${COMMENT_REGEX}") -gt 0 ]; then
            continue
        elif [ $(expr "${line}" : "${WHITESPACE_REGEX}") -gt 0 ]; then
            continue
        fi

        SYS_IMG_DIRS+=("${line}")
    done < "${SYS_IMG_FILE}"
} # read_sys_img_file()

check_files() {
    local msg=()

    println "Checking files"

    if [ -f "${SYS_IMG_DIR}/${RAMDISK_FILE}" ]; then
        println "[\033[0;32mOK\033[0m]   ${SYS_IMG_DIR}/${RAMDISK_FILE}"
    else
        println "[\033[0;31mFAIL\033[0m] ${SYS_IMG_DIR}/${RAMDISK_FILE}"
        msg+=("Ramdisk image cannot be found!")
    fi

    if [ -f "${SYS_IMG_DIR}/${SYSTEM_FILE}" ]; then
        println "[\033[0;32mOK\033[0m]   ${SYS_IMG_DIR}/${SYSTEM_FILE}"
    else
        println "[\033[0;31mFAIL\033[0m] ${SYS_IMG_DIR}/${SYSTEM_FILE}"
        msg+=("System image cannot be found!")
    fi

    ROOT_DIR=${ROOT_DIR%/}
    if [ -f "${ROOT_DIR}/bin/${MKBOOTFS_FILE}" ]; then
        println "[\033[0;32mOK\033[0m]   ${ROOT_DIR}/bin/${MKBOOTFS_FILE}"
    else
        println "[\033[0;31mFAIL\033[0m] ${ROOT_DIR}/bin/${MKBOOTFS_FILE}"
        msg+=("mkbootfs cannot be found. Please download a new setup package")
    fi

    if [ ${#msg[@]} -gt 0 ]; then
        for s in "${msg[@]}"; do
            std_err "${s}"
        done
        abort
    fi

    println ""
} # check_files()

prepare_filesystem() {
    println "Creating temporary directories"

    while [ -d "${ROOT_DIR}/${TMP_RAMDISK_DIR}" ]; do
        TMP_RAMDISK_DIR="${TMP_RAMDISK_DIR}0"
    done
    println "   ${ROOT_DIR}/${TMP_RAMDISK_DIR}"
    mkdir -p "${ROOT_DIR}/${TMP_RAMDISK_DIR}"

    while [ -d "${ROOT_DIR}/${TMP_MOUNT_DIR}" ]; do
        TMP_MOUNT_DIR="${TMP_MOUNT_DIR}0"
    done
    println "   ${ROOT_DIR}/${TMP_MOUNT_DIR}"
    mkdir -p "${ROOT_DIR}/${TMP_MOUNT_DIR}"

    println ""
} # prepare_filesystem()


cleanup() {
    println "   Removing temporary ramdisk directory"
    rm -r "${ROOT_DIR}/${TMP_RAMDISK_DIR}" &>/dev/null
    println "   Removing temporary mount directory"
    rm -r "${ROOT_DIR}/${TMP_MOUNT_DIR}" &>/dev/null
} # cleanup()

printResult() {
    if [ -z "${SUDO_PASSWORD}" ]; then
        println "NOTE: You are running without root privileges, some functionality might be suppressed.\nPlease use the --root flag.\nSee -h for more info\n"
    fi

    if [ ${SUCCESSES} -eq ${#SYS_IMG_DIRS[@]} ] && [ ${SUCCESSES} -gt 0 ]; then
        prefix="[\033[0;32mOK\033[0m]"
    else
        prefix="[\033[0;31mFAIL\033[0m]"
    fi
    println "${prefix} Success: ${SUCCESSES}/${#SYS_IMG_DIRS[@]}"
} # printResult()

run() {
    if [ ${#SYS_IMG_DIRS[@]} -eq 0 ]; then
        return 1
    fi

    println "${BANNER}"

    for i in "${SYS_IMG_DIRS[@]}"; do
        SYS_IMG_DIR="${i}"

        if [ -z "${SYS_IMG_DIR}" ] || [ ! -d "${SYS_IMG_DIR}" ]; then
            println "Error in system image path: ${SYS_IMG_DIR}"
            continue
        fi

        printfln "------------------------------------"
        println "Setup \"${SYS_IMG_DIR}\""
        println ""

        check_files
        prepare_filesystem

        println "Process ${RAMDISK_FILE}"
        ${ROOT_DIR}/modify/modify-ramdisk-img.sh ${SYS_IMG_DIR} ${TMP_RAMDISK_DIR} ${RAMDISK_FILE} ${DEFAULT_PROP_FILE} ${MKBOOTFS_FILE}
        println ""

        println "Process ${SYSTEM_FILE}"
        if [ ! -z "${SUDO_PASSWORD}" ]; then
            printf "${SUDO_PASSWORD}\n" | sudo -k -S -s ${ROOT_DIR}/modify/modify-system-img.sh ${SYS_IMG_DIR} ${TMP_MOUNT_DIR} ${SYSTEM_FILE} ${BUILD_PROP_FILE}
        else
            println "   No root privileges, skipping..."
        fi
        println ""

        println "Cleanup"
        cleanup
        printfln "------------------------------------"
        println ""

        ((SUCCESSES++))
    done
} # run()

setup
parse_arguments $@
read_conf
read_sys_img_file
run
printResult
