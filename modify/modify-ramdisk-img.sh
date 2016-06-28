#!/bin/bash

EXEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXEC_DIR="${EXEC_DIR%/}"
ROOT_DIR="$(cd "${EXEC_DIR}/.." && pwd)"
source ${ROOT_DIR}/utilities.sh

USAGE="Usage: ./modify-ramdisk-img.sh <system image dir> <ramdisk directory> [ramdisk image file] [default prop file] [mkbootfs file]"
HELP_TEXT="
OPTIONS
-s, --silent                Silent mode, suppresses all output except result
-h, --help                  Display this help and exit

<system image directory>    Directory of the installed system image
<ramdisk directory>         Directory where the ramdisk file is being unzipped to
[ramdisk image file]        OPTIONAL: The name of the ramdisk image file
                                default: ramdisk.img
[default prop file]         OPTIONAL: The name of the default property file
                                default: default.prop
[mkbootfs file]             OPTIONAL: The name of the mkbootfs binary
                                default: mkbootfs"

SYS_IMG_DIR=""
TMP_RAMDISK_DIR=""

RAMDISK_FILE="ramdisk.img"
DEFAULT_PROP_FILE="default.prop"
MKBOOTFS_FILE="mkbootfs"

parse_arguments() {
    local show_help=0
    for ((i = 1; i <= $#; i++)); do
        if [ "${!i}" == "-h" ] || [ "${!i}" == "--help" ]; then
            show_help=1
        elif [ "${!i}" == "-s" ] || [ "${!i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ -z "${SYS_IMG_DIR}" ]; then
            SYS_IMG_DIR="${!i}"
        elif [ -z "${TMP_RAMDISK_DIR}" ]; then
            TMP_RAMDISK_DIR="${!i}"
        elif [ -z "${RAMDISK_FILE}" ]; then
            RAMDISK_FILE="${!i}"
        elif [ -z "${DEFAULT_PROP_FILE}" ]; then
            DEFAULT_PROP_FILE="${!i}"
        elif [ -z "${MKBOOTFS_FILE}" ]; then
            MKBOOTFS_FILE="${!i}"
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

    if [ -z "${SYS_IMG_DIR}" ] \
    || [ -z "${TMP_RAMDISK_DIR}" ] \
    || [ -z "${RAMDISK_FILE}" ] \
    || [ -z "${DEFAULT_PROP_FILE}" ] \
    || [ -z "${MKBOOTFS_FILE}" ]; then
        println "${USAGE}"
        println "See -h for more info"
        exit 1
    fi
} # parse_arguments()

decompress_ramdisk() {
    println "   Decompressing ramdisk disc image"
    cd "${ROOT_DIR}/${TMP_RAMDISK_DIR}"
    {
        gzip -dc "${SYS_IMG_DIR}/${RAMDISK_FILE}" | cpio -i
    } &>/dev/null
    cd ..
} # decompress_ramdisk()

change_ramdisk_props() {
    println "   Modyfying ${DEFAULT_PROP_FILE}"

    if [ ! -f "${ROOT_DIR}/${TMP_RAMDISK_DIR}/${DEFAULT_PROP_FILE}" ]; then
        println "\033[0;31m${DEFAULT_PROP_FILE} is missing or you do not have access!\033[0m"
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
    println "   Compressing to ramdisk disc image"
    ("${ROOT_DIR}/bin/${MKBOOTFS_FILE}" "${ROOT_DIR}/${TMP_RAMDISK_DIR}" | gzip > "${SYS_IMG_DIR}/${RAMDISK_FILE}")
} # compress_ramdisk()

parse_arguments $@
decompress_ramdisk
change_ramdisk_props
compress_ramdisk
