#!/bin/bash

set -u

EXEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXEC_DIR="${EXEC_DIR%/}"
ROOT_DIR="$(cd "${EXEC_DIR}/.." && pwd)"
source ${ROOT_DIR}/utilities.sh

USAGE="Usage: ./modify-system-img.sh <system image dir> <mount directory> [system image file] [build prop file]"
HELP_TEXT="
OPTIONS
-s, --silent                Silent mode, suppresses all output except result
-h, --help                  Display this help and exit

<system image directory>    Directory of the installed system image
<mount directory>           Directory onto which the system.img file is being mounted
[system image file]         OPTIONAL: The name of the system image file
                                default: system.img
[build prop file]           OPTIONAL: The name of the build property file
                                default: build.prop"

SYS_IMG_DIR=""
TMP_MOUNT_DIR=""

SYSTEM_FILE=""
BUILD_PROP_FILE=""

parse_arguments() {
    local show_help=0
    for ((i = 1; i <= $#; i++)); do
        if [ "${!i}" == "-h" ] || [ "${!i}" == "--help" ]; then
            show_help=1
        elif [ "${!i}" == "-s" ] || [ "${!i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ -z "${SYS_IMG_DIR}" ]; then
            SYS_IMG_DIR="$1"
        elif [ -z "${TMP_MOUNT_DIR}" ]; then
            TMP_MOUNT_DIR="$2"
        elif [ -z "${SYSTEM_FILE}" ]; then
            SYSTEM_FILE="$3"
        elif [ -z "${BUILD_PROP_FILE}" ]; then
            BUILD_PROP_FILE="$4"
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

    if [ -z "${SYS_IMG_DIR}" ] \
    || [ -z "${TMP_MOUNT_DIR}" ] \
    || [ -z "${SYSTEM_FILE}" ] \
    || [ -z "${BUILD_PROP_FILE}" ]; then
        std_err "${USAGE}"
        std_err "See -h for more information"
        exit 1
    fi
} # parse_arguments()

mount_system() {
    clear_println "   Mounting system disc image"
    mount "${SYS_IMG_DIR}/${SYSTEM_FILE}" "${ROOT_DIR}/${TMP_MOUNT_DIR}"
} # mount_system()

change_system_props() {
    println "   Modifying ${BUILD_PROP_FILE}"

    if [ ! -f "${ROOT_DIR}/${TMP_MOUNT_DIR}/${BUILD_PROP_FILE}" ]; then
        std_err "\033[0;31m${BUILD_PROP_FILE} is missing!\033[0m"
        break
    fi

    cd "${ROOT_DIR}/${TMP_MOUNT_DIR}"

    local build_new="build_new.prop"
    while [ -f ${build_new} ]; do
        build_new="0${build_new}"
    done

    for key in "${!build_prop_changes[@]}"; do
        value=${build_prop_changes[${key}]}
        sed "s/${key}=.*/${key}=${value}/" "build.prop" > "${build_new}"
        mv "${build_new}" "build.prop"
    done
    cd ..
} # change_system_props()

unmount_system() {
    println "   Unmounting system disc image"
    local count=0
    local mountOutput="$(mount | grep "${ROOT_DIR}/${TMP_MOUNT_DIR}")"
    until [ -z "${mountOutput}" ]; do
        umount "${ROOT_DIR}/${TMP_MOUNT_DIR}"
        mountOutput="$(mount | grep "${ROOT_DIR}/${TMP_MOUNT_DIR}")"
        count=$((count + 1))
        if [ ${count} -gt 3 ]; then
            lsof "${ROOT_DIR}/${TMP_MOUNT_DIR}"
            fuser "${ROOT_DIR}/${TMP_MOUNT_DIR}"
            break
        fi
    done
} # unmount_system()

parse_arguments $@
mount_system
change_system_props
unmount_system
