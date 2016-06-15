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

USAGE="Usage: ./modify-env.sh [-s|--silent] <configuration file>"
HELP_TEXT="
OPTIONS
-s, --silent            Silent mode, supresses all output except result
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

    for i in $@; do
        if [ "${i}" == "-s" ] || [ "${i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ "${i}" == "-h" ] || [ "${i}" == "--help" ]; then
            println "${HELP_MSG}"
            exit
        else
            CONF_FILE="${i}"
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
            error "Unknown configuration key found!"
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
    rmdir "${EXEC_DIR}/${TMP_MOUNT_DIR}" &>/dev/null
} # cleanup()

printResult() {
    if [ $(id -u) -ne 0 ]; then
        println "\nNOTE: You are running without root privileges, some functionality might be supressed.\nSee -h for more info\n"
    fi

    if [ ${SUCCESSES} -eq ${#SYS_IMG_DIRS[@]} ] && [ ${SUCCESSES} -gt 0 ]; then
        prefix="[\033[0;32mOK\033[0m]"
    else
        prefix="[\033[0;31mFAIL\033[0m]"
    fi
    println "${prefix} Success: ${SUCCESSES}/${#SYS_IMG_DIRS[@]}"
} # printResult()

##########################
# Ramdisk.img functions
##########################

decompress_ramdisk() {
    message "   Decompressing ramdisk disc image"
    cd "${EXEC_DIR}/${TMP_RAMDISK_DIR}"
    {
        gzip -dc "${SYS_IMG_DIR}/${RAMDISK_FILE}" | cpio -i
    } &>/dev/null
    cd ..
} # decompress_ramdisk()

change_ramdisk_props() {
    message "   Modyfying ${DEFAULT_PROP_FILE}"

    if [ ! -f "${EXEC_DIR}/${TMP_RAMDISK_DIR}/${DEFAULT_PROP_FILE}" ]; then
        message "\033[0;31m${DEFAULT_PROP_FILE} is missing or you do not have access!\033[0m"
        abort
    fi

    cd "${EXEC_DIR}/${TMP_RAMDISK_DIR}"
    local default_new="default_new.prop"
    while [ -f ${default_new} ]; do
        default_new="0${default_new}"
    done

    for key in "${!default_prop_changes[@]}"; do
        value=${default_prop_changes[${key}]}
        sed "s/${key}=.*/${key}=${value}/" "default.prop" > ${default_new}
        mv ${default_new} "default.prop"
    done

    cd ..
} # change_ramdisk_props()

compress_ramdisk() {
    message "   Compressing to ramdisk disc image"
    ("${EXEC_DIR}/${MKBOOTFS_FILE}" "${EXEC_DIR}/${TMP_RAMDISK_DIR}" | gzip > "${SYS_IMG_DIR}/${RAMDISK_FILE}")
} # compress_ramdisk()

#########################
# System.img functions
#########################

mount_system() {
    message "   Mounting system disc image"
    mount "${SYS_IMG_DIR}/${SYSTEM_FILE}" "${EXEC_DIR}/${TMP_MOUNT_DIR}"
} # mount_system()

change_system_props() {
    message "   Modifying ${BUILD_PROP_FILE}"

    if [ ! -f "${EXEC_DIR}/${TMP_MOUNT_DIR}/${BUILD_PROP_FILE}" ]; then
        message "\033[0;31m${BUILD_PROP_FILE} is missing!\033[0m"
        abort
    fi

    cd "${EXEC_DIR}/${TMP_MOUNT_DIR}"
    local build_new="build_new.prop"
    while [ -f ${build_new} ]; do
        build_new="0${build_new}"
    done

    for key in "${!build_prop_changes[@]}"; do
        value=${build_prop_changes[${key}]}
        sed "s/${key}=.*/${key}=${value}/" "build.prop" > ${build_new}
        mv ${build_new} "build.prop"
    done

    cd ..
} # change_system_props()

unmount_system() {
    message "   Unmounting system disc image"
    local mountOutput="$(mount | grep "${EXEC_DIR}/${TMP_MOUNT_DIR}")"
    until [ -z "${mountOutput}" ]; do
        umount "${EXEC_DIR}/${TMP_MOUNT_DIR}" &>/dev/null
        mountOutput="$(mount | grep "${EXEC_DIR}/${TMP_MOUNT_DIR}")"
    done
} # unmount_system()

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
        decompress_ramdisk
        change_ramdisk_props
        compress_ramdisk
        message ""

        message "Process ${SYSTEM_FILE}"
        if [ $(id -u) -eq 0 ]; then
            mount_system
            change_system_props
            unmount_system
        else
            message "No root privileges, skipping..."
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
