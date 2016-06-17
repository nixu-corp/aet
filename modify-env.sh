#!/bin/bash

set -u

#############################
# Outline
#############################
# Global variables
#
# General functions
#   println()
#   printfln()
#   message()
#   fmessage()
#   error()
#   abort()
#   check_option_value()
#   setup()
#   parse_arguments()
#   read_conf()
#   read_sys_img_file()
#   check_files()
#   prepare_filesystem()
#   cleanup()
#   printResult()
#
# Ramdisk.img functions
#   decompress_ramdisk()
#   change_ramdisk_props()
#   compress_ramdisk()
#
# System.img functions
#   mount_system()
#   change_system_props()
#   unmount_system()
#
# Run loop
#   run()
#
# MAIN; Entry point
#
#############################

####################
# Global variables
####################

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

EXEC_DIR="$(pwd)"
TMP_RAMDISK_DIR="ramdisk"
TMP_MOUNT_DIR="mount"
SYS_IMG_DIR=""
MKBOOTFS_FILE="mkbootfs"
RAMDISK_FILE="ramdisk.img"
SYSTEM_FILE="system.img"

DEFAULT_PROP_FILE="default.prop"
BUILD_PROP_FILE="build.prop"

SILENT_MODE=0          # 0 = off, 1 = on
SUCCESSES=0

declare -a SYS_IMG_DIRS=()
declare -A default_prop_changes
declare -A build_prop_changes

#######################
# General functions
#######################

println() {
    if [ $# -eq 0 ]; then
        printf "\n"
    else
        printf "${1}\n"
    fi
} # println()

printfln() {
    if [ $# -eq 0 ]; then
        printf "\n"
    else
        printf "%s\n" "${1}"
    fi
} # printfln()

message() {
    if [ ${SILENT_MODE} -eq 0 ]; then
        println "${1}"
    fi
} # message()

fmessage() {
    if [ ${SILENT_MODE} -eq 0 ]; then
        printfln "${1}"
    fi
} # fmessage()

error() {
    message "$@" 1>&2
} # error()

abort() {
    message ""
    message "ABORTING..."
    message "Cleanup"
    cleanup
    println "\033[0;31mFailure!\033[0m"
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
    SILENT_MODE=0

    if [ $# -eq 0 ] || [ $# -gt 3 ]; then
        error "${USAGE}"
        error "See -h for more info"
        exit
    fi

    for ((i = 1; i <= $#; i++)); do
        if [ "${!i}" == "-r" ] || [ "${!i}" == "--root" ]; then
            i=$((i + 1))
            check_option_value ${i} $@
            if [ $? -eq 1 ]; then
                error "No sudo password given!\n"
                error "${USAGE}"
                error "See -h for more info"
                exit
            else
                SUDO_PASSWORD="${!i}"
            fi
        elif [ "${!i}" == "-s" ] || [ "${!i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ "${!i}" == "-h" ] || [ "${!i}" == "--help" ]; then
            println "${HELP_MSG}"
            exit
        else
            CONF_FILE="${!i}"
        fi
    done

    if [ ! -f ${CONF_FILE} ]; then
        error "Configuration file does not exist!"
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
        else
            error "Unknown configuration found: ${line}"
            abort
        fi
    done < "${CONF_FILE}"
} # read_conf()

read_sys_img_file() {
    if [ ! -f ${SYS_IMG_FILE} ]; then
        error "System image directory file cannot be found!"
        error "Please verify the path in the configuration file"
        exit
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

    message "Checking files"

    if [ -f "${SYS_IMG_DIR}/${RAMDISK_FILE}" ]; then
        message "[\033[0;32mOK\033[0m]   ${SYS_IMG_DIR}/${RAMDISK_FILE}"
    else
        message "[\033[0;31mFAIL\033[0m] ${SYS_IMG_DIR}/${RAMDISK_FILE}"
        msg+=("Ramdisk image cannot be found!")
    fi

    if [ -f "${SYS_IMG_DIR}/${SYSTEM_FILE}" ]; then
        message "[\033[0;32mOK\033[0m]   ${SYS_IMG_DIR}/${SYSTEM_FILE}"
    else
        message "[\033[0;31mFAIL\033[0m] ${SYS_IMG_DIR}/${SYSTEM_FILE}"
        msg+=("System image cannot be found!")
    fi

    if [ -f "${EXEC_DIR}/${MKBOOTFS_FILE}" ]; then
        message "[\033[0;32mOK\033[0m]   ${EXEC_DIR}/${MKBOOTFS_FILE}"
    else
        message "[\033[0;31mFAIL\033[0m] ${EXEC_DIR}/${MKBOOTFS_FILE}"
        msg+=("mkbootfs cannot be found. Please download a new setup package")
    fi

    if [ ${#msg[@]} -gt 0 ]; then
        for s in "${msg[@]}"; do
            error "${s}"
        done
        abort
    fi

    message ""
} # check_files()

prepare_filesystem() {
    message "Creating temporary directories"

    while [ -d "${EXEC_DIR}/${TMP_RAMDISK_DIR}" ]; do
        TMP_RAMDISK_DIR="${TMP_RAMDISK_DIR}0"
    done
    message "   ${EXEC_DIR}/${TMP_RAMDISK_DIR}"
    mkdir -p "${EXEC_DIR}/${TMP_RAMDISK_DIR}"

    while [ -d "${EXEC_DIR}/${TMP_MOUNT_DIR}" ]; do
        TMP_MOUNT_DIR="${TMP_MOUNT_DIR}0"
    done
    message "   ${EXEC_DIR}/${TMP_MOUNT_DIR}"
    mkdir -p "${EXEC_DIR}/${TMP_MOUNT_DIR}"

    message ""
} # prepare_filesystem()


cleanup() {
    message "   Removing temporary ramdisk directory"
    rm -r "${EXEC_DIR}/${TMP_RAMDISK_DIR}" &>/dev/null
    message "   Removing temporary mount directory"
    rm -r "${EXEC_DIR}/${TMP_MOUNT_DIR}" &>/dev/null
} # cleanup()

printResult() {
    if [ -z "${SUDO_PASSWORD}" ]; then
        println "\nNOTE: You are running without root privileges, some functionality might be suppressed.\nPlease use the --root flag.\nSee -h for more info\n"
    fi

    if [ ${SUCCESSES} -eq ${#SYS_IMG_DIRS[@]} ] && [ ${SUCCESSES} -gt 0 ]; then
        prefix="[\033[0;32mOK\033[0m]"
    else
        prefix="[\033[0;31mFAIL\033[0m]"
    fi
    println "${prefix} Success: ${SUCCESSES}/${#SYS_IMG_DIRS[@]}"
} # printResult()

########################
# Run loop
########################

run() {
    if [ ${#SYS_IMG_DIRS[@]} -eq 0 ]; then
        return
    fi

    message "${BANNER}"

    for i in "${SYS_IMG_DIRS[@]}"; do
        SYS_IMG_DIR="${i}"

        if [ -z "${SYS_IMG_DIR}" ] || [ ! -d "${SYS_IMG_DIR}" ]; then
            message "Error in system image path: ${SYS_IMG_DIR}"
            continue
        fi

        message "Setup \"${SYS_IMG_DIR}\""
        fmessage "------------------------------------"

        check_files
        prepare_filesystem

        message "Process ${RAMDISK_FILE}"
        ./modify-ramdisk-img.sh ${SYS_IMG_DIR} ${TMP_RAMDISK_DIR} ${RAMDISK_FILE} ${DEFAULT_PROP_FILE} ${MKBOOTFS_FILE}
        message ""

        message "Process ${SYSTEM_FILE}"
        if [ ! -z "${SUDO_PASSWORD}" ]; then
            printf "${SUDO_PASSWORD}\n" | sudo -k -S -s ./modify-system-img.sh ${SYS_IMG_DIR} ${TMP_MOUNT_DIR} ${SYSTEM_FILE} ${BUILD_PROP_FILE}
        else
            message "   No root privileges, skipping..."
        fi
        message ""

        message "Cleanup"
        cleanup
        fmessage "------------------------------------"

        ((SUCCESSES++))
    done
} # run()


########################
# MAIN; Entry point
########################
setup
parse_arguments $@
read_conf
read_sys_img_file
run
printResult
