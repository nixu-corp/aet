#!/bin/bash

EXEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXEC_DIR="${EXEC_DIR%/}"
ROOT_DIR="$(cd "${EXEC_DIR}/.." && pwd)"
ROOT_DIR="${ROOT_DIR%/}"
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

RAMDISK_FILE=""
DEFAULT_PROP_FILE=""
MKBOOTFS_FILE=""

parse_arguments() {
    local show_help=0
    for ((i = 1; i <= $#; i++)); do
        if [ "${!i}" == "-h" ] || [ "${!i}" == "--help" ]; then
            show_help=1
        elif [ "${!i}" == "-s" ] || [ "${!i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ -z "${SYS_IMG_DIR}" ]; then
            SYS_IMG_DIR="${!i}"
            SYS_IMG_DIR="${SYS_IMG_DIR%/}"
        elif [ -z "${TMP_RAMDISK_DIR}" ]; then
            TMP_RAMDISK_DIR="${!i}"
            TMP_RAMDISK_DIR="${TMP_RAMDISK_DIR%/}"
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
    || [ -z "${TMP_RAMDISK_DIR}" ]; then
        std_err "${USAGE}"
        std_err "See -h for more info"
        exit 1
    fi

    if [ ! -d ${SYS_IMG_DIR} ]; then
        std_err "System image directory does not exist!"
        exit 1
    fi

    while [ -d ${ROOT_DIR}/${TMP_RAMDISK_DIR} ]; do
        TMP_RAMDISK_DIR="${TMP_RAMDISK_DIR}-new"
    done

    mkdir -p "${ROOT_DIR}/${TMP_RAMDISK_DIR}"

    if [ ! -d ${ROOT_DIR}/${TMP_RAMDISK_DIR} ]; then
        stderr "Temporary ramdisk directory cannot be created!"
        exit 1
    fi

    if [ -z "${RAMDISK_FILE}" ]; then
        RAMDISK_FILE="ramdisk.img"
    fi

    if [ -z "${DEFAULT_PROP_FILE}" ]; then
        DEFAULT_PROP_FILE="default.prop"
    fi

    if [ -z "${MKBOOTFS_FILE}" ]; then
        MKBOOTFS_FILE="mkbootfs"
    fi
} # parse_arguments()

decompress_ramdisk() {
    local ret=0
    cd "${ROOT_DIR}/${TMP_RAMDISK_DIR}"
    {
        gzip -dc "${SYS_IMG_DIR}/${RAMDISK_FILE}" | cpio -i
        ret=$?
    } &>/dev/null
    cd ..
    if [ ${ret} -eq 0 ]; then
        println "   [\033[0;32m OK \033[0m] Decompressing \033[1;35m${RAMDISK_FILE}\033[0m"
    else
        println "   [\033[0;31mFAIL\033[0m] Decompressing \033[1;35m${RAMDISK_FILE}\033[0m"
    fi
    return ${ret}
} # decompress_ramdisk()

change_ramdisk_props() {
    local ret=0

    if [ ! -f "${ROOT_DIR}/${TMP_RAMDISK_DIR}/${DEFAULT_PROP_FILE}" ]; then
        std_err "   \033[0;31m${DEFAULT_PROP_FILE} is missing or you do not have access!\033[0m"
        ret=1
    fi

    if [ ${ret} -eq 0 ]; then
        cd "${ROOT_DIR}/${TMP_RAMDISK_DIR}"
        local default_new="0${DEFAULT_PROP_FILE}"
        while [ -f ${default_new} ]; do
            default_new="0${default_new}"
        done

        for key in "${!default_prop_changes[@]}"; do
            value=${default_prop_changes[${key}]}
            sed "s/${key}=.*/${key}=${value}/" "${DEFAULT_PROP_FILE}" > ${default_new}
            mv ${default_new} "${DEFAULT_PROP_FILE}"
        done
        cd ..
    fi

    if [ ${ret} -eq 0 ]; then
        println "   [\033[0;32m OK \033[0m] Modifying     \033[1;35m${DEFAULT_PROP_FILE}\033[0m"
    else
        println "   [\033[0;31mFAIL\033[0m] Modifying     \033[1;35m${DEFAULT_PROP_FILE}\033[0m"
    fi

    return ${ret}
} # change_ramdisk_props()

compress_ramdisk() {
    local ret=0
    ("${ROOT_DIR}/bin/${MKBOOTFS_FILE}" "${ROOT_DIR}/${TMP_RAMDISK_DIR}" | gzip > "${SYS_IMG_DIR}/${RAMDISK_FILE}")
    ret=$?

    if [ ${ret} -eq 0 ]; then
        println "   [\033[0;32m OK \033[0m] Compressing   \033[1;35m${RAMDISK_FILE}\033[0m"
    else
        println "   [\033[0;31mFAIL\033[0m] Compressing   \033[1;35m${RAMDISK_FILE}\033[0m"
    fi

    return ${ret}
} # compress_ramdisk()

cleanup() {
    rm -r "${ROOT_DIR}/${TMP_RAMDISK_DIR}" &>/dev/null
    if [ $? -eq 0 ]; then
        println "   [\033[0;32m OK \033[0m] Cleanup"
    else
        println "   [\033[0;31mFAIL\033[0m] Cleanup"
    fi
} # cleanup

parse_arguments $@
decompress_ramdisk && [ $? -eq 0 ] && change_ramdisk_props && [ $? -eq 0 ] && compress_ramdisk
cleanup
