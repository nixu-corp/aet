#!/bin/bash

set -u

#####################
# Outline
#####################
# Global variables
#
# General functions
#   message()
#   error()
#   abort()
#   setup()
#   parse_arguments()
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

####################
# Global variables
####################

read -d '' USAGE << "EOF"
Usage: ./setup-env.sh [-s] [-f <path file>] <paths>
See -h for more info
EOF

read -d '' help_text << "EOF"
-s                     Silent mode, supresses all output except result

-f <path file>         Specify a file with system image directory paths, each
                       directory path on its own row

<paths>                List paths as arguments, these are appended to the
                       existing list in case -f is used
EOF

HELP_MSG="${USAGE}\n\n\n${help_text}"


EXEC_DIR="$(pwd)"
TMP_RAMDISK_DIR="ramdisk"
TMP_MOUNT_DIR="mount"
SYS_IMG_DIR=""
MKBOOTFS_FILE="mkbootfs"
RAMDISK_FILE="ramdisk.img"
SYSTEM_FILE="system.img"

DEFAULT_PROP_FILE="default.prop"
BUILD_PROP_FILE="build.prop"

declare -i SILENT_MODE=0          # 0 = off, 1 = on
declare -i SUCCESSES=0
declare -a SYS_IMG_DIRS=()
declare -A default_prop_changes
declare -A build_prop_changes

#######################
# General functions
#######################

message() {
    if [ ${SILENT_MODE} -eq 0 ]; then
        echo -e "${1}"
    fi
} # message()

error() {
    message "$@" 1>&2
} # error()

abort() {
    message ""
    message "ABORTING..."
    message "Cleanup"
    cleanup
    echo -e "\e[0;31mFailure!\e[0m"
    exit
} # abort()

setup() {
    default_prop_changes["ro.secure"]="1"

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

    while getopts ":hsf:" opt; do
        case $opt in
            s)
                SILENT_MODE=1
                ;;
            f)
                if [ ! -f "${OPTARG}" ]; then
                    error "Invalid argument"
                    abort
                fi

                while read line; do
                    if [[ -z $line ]] || [[ $line =~ \#.* ]]; then
                        continue
                    fi

                    SYS_IMG_DIRS+=("${line}")
                done < "${OPTARG}"
                ;;
            h)
                echo -e "${HELP_MSG}"
                exit
                ;;
            *)
                error "${USAGE}"
                exit
                ;;
        esac
    done


    for (( i=${OPTIND}; i <= $#; i++ )); do
        dir="${!i}"

        # Check if paths are added before options
        if [[ ${dir} =~ -. ]]; then
            error "${USAGE}"
            exit
        fi

        SYS_IMG_DIRS+=(${dir})
    done

    if [ ${#SYS_IMG_DIRS[@]} -eq 0 ]; then
        error "${USAGE}"
        exit
    fi
} # parse_arguments()

check_files() {
    local msg=()

    message "Checking files"

    if [ -f "${SYS_IMG_DIR}/${RAMDISK_FILE}" ]; then
        message "[\e[0;32mOK\e[0m]   ${SYS_IMG_DIR}/${RAMDISK_FILE}"
    else
        message "[\e[0;31mFAIL\e[0m] ${SYS_IMG_DIR}/${RAMDISK_FILE}"
        msg+=("Ramdisk image cannot be found!")
    fi

    if [ -f "${SYS_IMG_DIR}/${SYSTEM_FILE}" ]; then
        message "[\e[0;32mOK\e[0m]   ${SYS_IMG_DIR}/${SYSTEM_FILE}"
    else
        message "[\e[0;31mFAIL\e[0m] ${SYS_IMG_DIR}/${SYSTEM_FILE}"
        msg+=("System image cannot be found!")
    fi

    if [ -f "${EXEC_DIR}/${MKBOOTFS_FILE}" ]; then
        message "[\e[0;32mOK\e[0m]   ${EXEC_DIR}/${MKBOOTFS_FILE}"
    else
        message "[\e[0;31mFAIL\e[0m] ${EXEC_DIR}/${MKBOOTFS_FILE}"
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
    if [ ${EUID} -ne 0 ]; then
        echo -e "\nNOTE: You are running without root privileges, some functionality might be supressed.\nSee -h for more info\n"
    fi

    if [ ${SUCCESSES} -eq ${#SYS_IMG_DIRS[@]} ]; then
        prefix="[\e[0;32mOK\e[0m]"
    else
        prefix="[\e[0;31mFAIL\e[0m]"
    fi
    echo -e "${prefix} Success: ${SUCCESSES}/${#SYS_IMG_DIRS[@]}"
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
        message "\e[0;31m${DEFAULT_PROP_FILE} is missing or you do not have access!\e[0m"
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
        message "\e[0;31m${BUILD_PROP_FILE} is missing!\e[0m"
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
    for i in "${SYS_IMG_DIRS[@]}"; do
        SYS_IMG_DIR="${i}"

        if [[ -z "${SYS_IMG_DIR}" ]] || [[ ! -d "${SYS_IMG_DIR}" ]]; then
            message "Error in system image path: ${SYS_IMG_DIR}"
            continue
        fi

        cd "${SYS_IMG_DIR}"
        message "Setup \"${SYS_IMG_DIR}\""
        message "-------------------"

        check_files
        prepare_filesystem

        message "Process ${RAMDISK_FILE}"
        decompress_ramdisk
        change_ramdisk_props
        compress_ramdisk
        message ""

        message "Process ${SYSTEM_FILE}"
        if [ ${EUID} -eq 0 ]; then
            mount_system
            change_system_props
            unmount_system
        else
            message "No root privileges, skipping..."
        fi
        message ""

        message "Cleanup"
        cleanup
        message "-------------------"

        ((SUCCESSES++))
    done
} # run()

########################
# Main; Entry point
########################
setup
parse_arguments $@
run
printResult
