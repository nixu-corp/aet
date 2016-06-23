#!/bin/bash

EXEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${EXEC_DIR}/.." && pwd)"
SYS_IMG_DIR=""
TMP_RAMDISK_DIR=""

RAMDISK_FILE=""
DEFAULT_PROP_FILE=""
MKBOOTFS_FILE=""

parse_arguments() {
    if [ $# -ne 5 ]; then
        exit
    fi

    SYS_IMG_DIR="$1"
    TMP_RAMDISK_DIR="$2"
    RAMDISK_FILE="$3"
    DEFAULT_PROP_FILE="$4"
    MKBOOTFS_FILE="$5"
} # parse_arguments()

decompress_ramdisk() {
    printf "   Decompressing ramdisk disc image\n"
    cd "${ROOT_DIR}/${TMP_RAMDISK_DIR}"
    {
        gzip -dc "${SYS_IMG_DIR}/${RAMDISK_FILE}" | cpio -i
    } &>/dev/null
    cd ..
} # decompress_ramdisk()

change_ramdisk_props() {
    printf "   Modyfying ${DEFAULT_PROP_FILE}\n"

    if [ ! -f "${ROOT_DIR}/${TMP_RAMDISK_DIR}/${DEFAULT_PROP_FILE}" ]; then
        printf "\033[0;31m${DEFAULT_PROP_FILE} is missing or you do not have access!\033[0m\n"
        exit
    fi

    cd "${ROOT_DIR}/${TMP_RAMDISK_DIR}"
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
    printf "   Compressing to ramdisk disc image\n"
    ("${ROOT_DIR}/bin/${MKBOOTFS_FILE}" "${ROOT_DIR}/${TMP_RAMDISK_DIR}" | gzip > "${SYS_IMG_DIR}/${RAMDISK_FILE}")
} # compress_ramdisk()

parse_arguments $@
decompress_ramdisk
change_ramdisk_props
compress_ramdisk
