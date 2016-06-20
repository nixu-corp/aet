#!/bin/bash

set -u

EXEC_DIR="$(pwd)"
SYS_IMG_DIR=""
TMP_MOUNT_DIR=""

SYSTEM_FILE=""
BUILD_PROP_FILE=""

parse_arguments() {
    if [ $# -ne 4 ]; then
        exit
    fi

    SYS_IMG_DIR="$1"
    TMP_MOUNT_DIR="$2"
    SYSTEM_FILE="$3"
    BUILD_PROP_FILE="$4"
} # parse_arguments()

mount_system() {
    printf "   Mounting system disc image\n"
    mount "${SYS_IMG_DIR}/${SYSTEM_FILE}" "${EXEC_DIR}/${TMP_MOUNT_DIR}"
} # mount_system()

change_system_props() {
    printf "   Modifying ${BUILD_PROP_FILE}\n"

    if [ ! -f "${EXEC_DIR}/${TMP_MOUNT_DIR}/${BUILD_PROP_FILE}" ]; then
        printf "\033[0;31m${BUILD_PROP_FILE} is missing!\033[0m\n"
        break
    fi

    cd "${EXEC_DIR}/${TMP_MOUNT_DIR}"

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
    printf "   Unmounting system disc image\n"
    local count=0
    local mountOutput="$(mount | grep "${EXEC_DIR}/${TMP_MOUNT_DIR}")"
    until [ -z "${mountOutput}" ]; do
        umount "${EXEC_DIR}/${TMP_MOUNT_DIR}"
        mountOutput="$(mount | grep "${EXEC_DIR}/${TMP_MOUNT_DIR}")"
        count=$((count + 1))
        if [ ${count} -gt 3 ]; then
            lsof "${EXEC_DIR}/${TMP_MOUNT_DIR}"
            fuser "${EXEC_DIR}/${TMP_MOUNT_DIR}"
            break
        fi
    done
} # unmount_system()

printf "\r$(tput el)"
parse_arguments $@
mount_system
change_system_props
unmount_system
