#!/bin/bash

set -u

EXEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXEC_DIR="${EXEC_DIR%/}"
ROOT_DIR="$(cd "${EXEC_DIR}/.." && pwd)"
ROOT_DIR="${ROOT_DIR%/}"
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
            SYS_IMG_DIR="${!i}"
        elif [ -z "${TMP_MOUNT_DIR}" ]; then
            TMP_MOUNT_DIR="${!i}"
        elif [ -z "${SYSTEM_FILE}" ]; then
            SYSTEM_FILE="${!i}"
        elif [ -z "${BUILD_PROP_FILE}" ]; then
            BUILD_PROP_FILE="${!i}"
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
    || [ -z "${TMP_MOUNT_DIR}" ]; then
        std_err "${USAGE}"
        std_err "See -h for more information"
        exit 1
    fi

    if [ ! -d ${SYS_IMG_DIR} ]; then
        std_err "System image directory does not exist!"
        exit 1
    fi

    while [ -d ${ROOT_DIR}/${TMP_MOUNT_DIR} ]; do
        TMP_MOUNT_DIR="${TMP_MOUNT_DIR}-new"
    done

    mkdir -p "${ROOT_DIR}/${TMP_MOUNT_DIR}"

    if [ ! -d ${ROOT_DIR}/${TMP_MOUNT_DIR} ]; then
        stderr "Temporary mount directory cannot be created!"
        exit 1
    fi

    if [ -z "${SYSTEM_FILE}" ]; then
        SYSTEM_FILE="system.img"
    fi

    if [ -z "${BUILD_PROP_FILE}" ]; then
        BUILD_PROP_FILE="build.prop"
    fi
} # parse_arguments()

mount_system() {
    local ret=0
    write "    "
    mount "${SYS_IMG_DIR}/${SYSTEM_FILE}" "${ROOT_DIR}/${TMP_MOUNT_DIR}"
    ret=$?
    clear_print ""

    if [ ${ret} -eq 0 ]; then
        println "   [\033[0;32m OK \033[0m] Mounting   \033[1;35m${SYSTEM_FILE}\033[0m"
    else
        println "   [\033[0;31mFAIL\033[0m] Mounting   \033[1;35m${SYSTEM_FILE}\033[0m"
    fi
    return ${ret}
} # mount_system()

change_system_props() {
    local ret=0
    if [ ! -f "${ROOT_DIR}/${TMP_MOUNT_DIR}/${BUILD_PROP_FILE}" ]; then
        std_err "    \033[0;31m${BUILD_PROP_FILE} is missing!\033[0m"
        ret=1
    fi

    if [ ${ret} -eq 0 ]; then
        cd "${ROOT_DIR}/${TMP_MOUNT_DIR}"

        local build_new="build_new.prop"
        while [ -f ${build_new} ]; do
            build_new="0${build_new}"
        done

        for key in "${!build_prop_changes[@]}"; do
            value=${build_prop_changes[${key}]}
            sed "s/${key}=.*/${key}=${value}/" "${BUILD_PROP_FILE}" > "${build_new}"
            mv "${build_new}" "${BUILD_PROP_FILE}"
        done
        cd ..
    fi

    if [ ${ret} -eq 0 ]; then
        println "   [\033[0;32m OK \033[0m] Modifying  \033[1;35m${BUILD_PROP_FILE}\033[0m"
    else
        println "   [\033[0;31mFAIL\033[0m] Modifying  \033[1;35m${BUILD_PROP_FILE}\033[0m"
    fi
    return ${ret}
} # change_system_props()

unmount_system() {
    local ret=0
    local count=0
    local mountOutput="$(mount | grep "${ROOT_DIR}/${TMP_MOUNT_DIR}")"
    until [ -z "${mountOutput}" ]; do
        umount "${ROOT_DIR}/${TMP_MOUNT_DIR}" &>/dev/null
        mountOutput="$(mount | grep "${ROOT_DIR}/${TMP_MOUNT_DIR}")"
        count=$((count + 1))
        if [ ${count} -gt 3 ]; then
            ret=1
        fi
    done

    if [ ${ret} -eq 0 ]; then
        println "   [\033[0;32m OK \033[0m] Unmounting \033[1;35m${SYSTEM_FILE}\033[0m"
    else
        println "   [\033[0;31mFAIL\033[0m] Unmounting \033[1;35m${SYSTEM_FILE}\033[0m"
    fi
    return ${ret}
} # unmount_system()

cleanup() {
    rm -r ${ROOT_DIR}/${TMP_MOUNT_DIR} &>/dev/null
    if [ $? -eq 0 ]; then
        println "   [\033[0;32m OK \033[0m] Cleanup"
    else
        println "   [\033[0;31mFAIL\033[0m] Cleanup"
    fi
} # cleanup

parse_arguments $@
clear_print ""
mount_system && [ $? -eq 0 ] && change_system_props && [ $? -eq 0 ] && unmount_system
cleanup
