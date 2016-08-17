#!/bin/bash

set -u

EXEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXEC_DIR=${EXEC_DIR%/}
ROOT_DIR="$(cd "${EXEC_DIR}/.." && pwd)"
source ${ROOT_DIR}/utilities.sh

USAGE="Usage: ./emulation-detection-evasion-env.sh [-b|--backup] [-s|--silent] <configuration file>"
HELP_TEXT="
OPTIONS
-b, --backup            Backups before making any modifications, use
                        this if you plan on reverting back at some
                        point
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

BACKUP_DIR=""
BACKUP_POSTFIX=""
CONF_FILE=""
SYS_IMG_FILE=""
ROOT_PASSWORD=""

WHITESPACE_REGEX="^[[:blank:]]*$"
COMMENT_REGEX="^[[:blank:]]*#"
SYS_IMG_REGEX="^system_img_dir_file[[:blank:]]*=[[:blank:]]*\(.*\)"
RAM_MOD_REGEX="^ramdisk_modification_file[[:blank:]]*=[[:blank:]]*\(.*\)"
SYS_MOD_REGEX="^system_modification_file[[:blank:]]*=[[:blank:]]*\(.*\)"
BACKUP_DIR_REGEX="^backup_directory[[:blank:]]*=[[:blank:]]*\(.*\)"
BACKUP_POSTFIX_REGEX="^backup_filename_postfix[[:blank:]]*=[[:blank:]]*\(.*\)"

TMP_RAMDISK_DIR="ramdisk"
TMP_MOUNT_DIR="mount"
SYS_IMG_DIR=""
RAMDISK_MODIFICATION_FILE=""
SYSTEM_MODIFICATION_FILE=""
MKBOOTFS_FILE="mkbootfs"
SYSTEM_FILE="system.img"
RAMDISK_FILE="ramdisk.img"

DO_BACKUP=0
SUCCESSES=0

declare -a SYS_IMG_DIRS=()
declare -A default_prop_changes
declare -A build_prop_changes

parse_arguments() {
    local show_help=0
    for ((i = 1; i <= $#; i++)); do
        if [ "${!i}" == "-s" ] || [ "${!i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ "${!i}" == "-h" ] || [ "${!i}" == "--help" ]; then
            show_help=1
        elif [ "${!i}" == "-b" ] || [ "${!i}" == "--backup" ]; then
            DO_BACKUP=1
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
        exit 1
    fi

    [ $(id -u) -eq 0 ] || prompt_root &>/dev/null
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
        local ramdisk_mod_file_capture=$(expr "${line}" : "${RAM_MOD_REGEX}")
        local system_mod_file_capture=$(expr "${line}" : "${SYS_MOD_REGEX}")
        local backup_dir_capture=$(expr "${line}" : "${BACKUP_DIR_REGEX}")
        local backup_postfix_capture=$(expr "${line}" : "${BACKUP_POSTFIX_REGEX}")
        if [ ! -z "${sys_img_dir_file_capture}" ]; then
            SYS_IMG_FILE="${sys_img_dir_file_capture}"
            SYS_IMG_FILE="${SYS_IMG_FILE/\~/${HOME}}"
        elif [ ! -z "${ramdisk_mod_file_capture}" ]; then
            RAMDISK_MODIFICATION_FILE="${ramdisk_mod_file_capture}"
            RAMDISK_MODIFICATION_FILE="${RAMDISK_MODIFICATION_FILE/\~/${HOME}}"
        elif [ ! -z "${system_mod_file_capture}" ]; then
            SYSTEM_MODIFICATION_FILE="${system_mod_file_capture}"
            SYSTEM_MODIFICATION_FILE="${SYSTEM_MODIFICATION_FILE/\~/${HOME}}"
        elif [ ! -z "${backup_dir_capture}" ]; then
            BACKUP_DIR="${backup_dir_capture}"
        elif [ ! -z "${backup_postfix_capture}" ] || [ -z "${backup_postfix_capture}" ]; then
            BACKUP_POSTFIX="${backup_postfix_capture}"
        else
            std_err "Unknown configuration found: ${line}"
            exit 1
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

        line="${line%/}"
        SYS_IMG_DIRS+=("${line/\~/${HOME}}")
    done < "${SYS_IMG_FILE}"

    if [ ${#SYS_IMG_DIRS[@]} -eq 0 ]; then
        std_err "No system images specified!"
        std_err "Please add some to ${SYS_IMG_FILE}"
        exit 1
    fi
} # read_sys_img_file()

check_files() {
    local msg=()

    println "Checking files"

    if [ -f "${SYS_IMG_DIR}/${RAMDISK_FILE}" ]; then
        println "[\033[0;32m OK \033[0m] ${SYS_IMG_DIR}/${RAMDISK_FILE}"
    else
        println "[\033[0;31mFAIL\033[0m] ${SYS_IMG_DIR}/${RAMDISK_FILE}"
        msg+=("Ramdisk image cannot be found!")
    fi

    if [ -f "${SYS_IMG_DIR}/${SYSTEM_FILE}" ]; then
        println "[\033[0;32m OK \033[0m] ${SYS_IMG_DIR}/${SYSTEM_FILE}"
    else
        println "[\033[0;31mFAIL\033[0m] ${SYS_IMG_DIR}/${SYSTEM_FILE}"
        msg+=("System image cannot be found!")
    fi

    ROOT_DIR=${ROOT_DIR%/}
    if [ -f "${ROOT_DIR}/bin/${MKBOOTFS_FILE}" ]; then
        println "[\033[0;32m OK \033[0m] ${ROOT_DIR}/bin/${MKBOOTFS_FILE}"
    else
        println "[\033[0;31mFAIL\033[0m] ${ROOT_DIR}/bin/${MKBOOTFS_FILE}"
        msg+=("mkbootfs cannot be found. Please download a new setup package")
    fi

    if [ ${#msg[@]} -gt 0 ]; then
        for s in "${msg[@]}"; do
            std_err "${s}"
        done
        exit 1
    fi

    println ""
} # check_files()

printResult() {
    if [ $(id -u) -ne 0 ] && [ -z "${ROOT_PASSWORD}" ]; then
        println "NOTE: You are running without root privileges, some functionality might be suppressed."
        println "See -h for more information"
    fi

    if [ ${SUCCESSES} -eq ${#SYS_IMG_DIRS[@]} ] && [ ${SUCCESSES} -gt 0 ]; then
        prefix="[\033[0;32m OK \033[0m]"
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

    local modifier=""
    if [ ${DO_BACKUP} -eq 1 ]; then
        if [ -z "${BACKUP_POSTFIX}" ]; then
            BACKUP_POSTFIX="_$(date +%F-%H-%M-%S).bak"
        fi
        modifier="--backup ${BACKUP_DIR} ${BACKUP_POSTFIX}"
    fi

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

        println "Process ${RAMDISK_FILE}"
        ${ROOT_DIR}/modify/modify-ramdisk-img.sh ${modifier} ${SYS_IMG_DIR} ${TMP_RAMDISK_DIR} ${RAMDISK_MODIFICATION_FILE}
        println ""

        println "Process ${SYSTEM_FILE}"
        if [ $(id -u) -eq 0 ]; then
            ${ROOT_DIR}/modify/modify-system-img.sh ${modifier} ${SYS_IMG_DIR} ${TMP_MOUNT_DIR} ${SYSTEM_MODIFICATION_FILE}
        elif [ ! -z "${ROOT_PASSWORD}" ]; then
            printf "${ROOT_PASSWORD}\n" | sudo -k -S -s ${ROOT_DIR}/modify/modify-system-img.sh ${modifier} ${SYS_IMG_DIR} ${TMP_MOUNT_DIR} ${SYSTEM_MODIFICATION_FILE}
        else
            println "   No root privileges, skipping..."
        fi
        println ""

        ((SUCCESSES++))
    done
} # run()

parse_arguments $@
read_conf
read_sys_img_file
run
printResult
