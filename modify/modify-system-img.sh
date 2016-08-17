#!/bin/bash

set -u

EXEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXEC_DIR="${EXEC_DIR%/}"
ROOT_DIR="$(cd "${EXEC_DIR}/.." && pwd)"
ROOT_DIR="${ROOT_DIR%/}"
source ${ROOT_DIR}/utilities.sh

USAGE="Usage: ./modify-system-img.sh [-b <backup directory> <backup file postfix>] <system image dir> <mount directory> <modification file> [system image file] [build prop file] [-s|--silent]"
HELP_TEXT="
OPTIONS
-b, --backup                Backups before making any modifications, use
                            this if you plan on reverting back at some
                            point
-s, --silent                Silent mode, suppresses all output except result
-h, --help                  Display this help and exit

<backup directory>          The directory where to store the backups
<backup file postfix>       A postfix after the backup filename
<system image directory>    Directory of the installed system image
<mount directory>           Directory onto which the system.img file is being mounted
<modification file>         File with the modifications in key-value pairs"

MODIFICATION_FILE=""
SYS_IMG_DIR=""
TMP_MOUNT_DIR=""
BACKUP_DIR=""
BACKUP_POSTFIX=""

SYSTEM_FILE="system.img"
BUILD_PROP_FILE="build.prop"

WHITESPACE_REGEX="^[[:blank:]]*$"
COMMENT_REGEX="^[[:blank:]]*#"
KEY_REGEX="^[[:blank:]]*\(.*\)=.*$"
VALUE_REGEX="^.*=\(.*\)$"

declare -A build_prop_changes=()

parse_arguments() {
    local show_help=0
    for ((i = 1; i <= $#; i++)); do
        if [ "${!i}" == "-h" ] || [ "${!i}" == "--help" ]; then
            show_help=1
        elif [ "${!i}" == "-s" ] || [ "${!i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ "${!i}" == "-b" ] || [ "${!i}" == "--backup" ]; then
            for ((j = 0; j < 2; j++)); do
                argument_parameter_exists ${i} $@
                if [ $? -eq 1 ]; then
                    if [ -z "${BACKUP_DIR}" ]; then
                        std_err "No backup directory given for '-b'!\n"
                    else
                        std_err "No backup postfix given for '-b'!\n"
                    fi
                    std_err "${USAGE}"
                    std_err "See -h for more information"
                elif [ -z "${BACKUP_DIR}" ]; then
                    i=$((i + 1))
                    BACKUP_DIR="${!i}"
                    BACKUP_DIR="${BACKUP_DIR%/}"
                else
                    i=$((i + 1))
                    BACKUP_POSTFIX="${!i}"
                fi
            done
        elif [ -z "${SYS_IMG_DIR}" ]; then
            SYS_IMG_DIR="${!i}"
            SYS_IMG_DIR="${SYS_IMG_DIR/\~/${HOME}}"
        elif [ -z "${TMP_MOUNT_DIR}" ]; then
            TMP_MOUNT_DIR="${!i}"
            TMP_MOUNT_DIR="${TMP_MOUNT_DIR/\~/${HOME}}"
        elif [ -z "${MODIFICATION_FILE}" ]; then
            MODIFICATION_FILE="${!i}"
            MODIFICATION_FILE="${MODIFICATION_FILE/\~/${HOME}}"
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
    || [ -z "${MODIFICATION_FILE}" ]; then
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

    if [ ! -f "${MODIFICATION_FILE}" ]; then
        std_err "Modification file does not exist!"
        exit 1
    fi
} # parse_arguments()

setup() {
    local current_prop=""
    while read line; do
        if [ "${line}" == "@${BUILD_PROP_FILE}" ]; then
            current_prop="build_prop"
            continue
        elif [ "${line}" == "@" ]; then
            current_prop=""
            continue
        fi

        [ "${current_prop}" == "build_prop" ] && parse_build_prop_change "${line}"
    done < "${MODIFICATION_FILE}"

    [ ${#build_prop_changes[@]} -eq 0 ] && println "WARNING: No changes to be made to ${BUILD_PROP_FILE}"
} # setup()

parse_build_prop_change() {
    local line="${1}"

    if [ $(expr "${line}" : "${COMMENT_REGEX}") -gt 0 ]; then
        continue
    elif [ $(expr "${line}" : "${WHITESPACE_REGEX}") -gt 0 ]; then
        continue
    elif [ -z "${line}" ]; then
        continue
    fi

    local key_capture=$(expr "${line}" : "${KEY_REGEX}")
    local value_capture=$(expr "${line}" : "${VALUE_REGEX}")
    if [ ! -z "${key_capture}" ]; then
        build_prop_changes["${key_capture}"]="${value_capture}"
    else
        std_err "Unknown configuration found: ${line}"
        exit 1
    fi
} # parse_build_prop_change()

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

backup_system_props() {
    local ret=0

    [ ! -z "${BACKUP_DIR}" ] || return 0

    if [ ! -f "${ROOT_DIR}/${TMP_MOUNT_DIR}/${BUILD_PROP_FILE}" ]; then
        std_err "   \033[0;31m${BUILD_PROP_FILE} is missing or you do not have access!\033[0m"
        ret=1
    fi

    local backup_file="system${BACKUP_POSTFIX}"

    if [ ${ret} -eq 0 ]; then
        [ -f ${BACKUP_DIR}/${backup_file} ] && rm ${BACKUP_DIR}/${backup_file} &>/dev/null

        printf "@${BUILD_PROP_FILE}\n" >> ${BACKUP_DIR}/${backup_file}
        while read line; do
            local key_capture=$(expr "${line}" : "${KEY_REGEX}")
            local value_capture=$(expr "${line}" : "${VALUE_REGEX}")
            if [ -z "${key_capture}" ]; then
                continue
            fi

            for key in ${!build_prop_changes[@]}; do
                if [ "${key}" == "${key_capture}" ]; then
                    printf "${key_capture}=${value_capture}\n" >> ${BACKUP_DIR}/${backup_file}
                    break
                fi
            done
        done < "${ROOT_DIR}/${TMP_MOUNT_DIR}/${BUILD_PROP_FILE}"
    fi

    if [ ${ret} -eq 0 ]; then
        println "   [\033[0;32m OK \033[0m] Backing up"
    else
        println "   [\033[0;31mFAIL\033[0m] Backing up"
    fi

    return ${ret}
} # backup_system_props()

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
        if [ ${count} -gt 5 ]; then
            ret=1
            break
        fi
        sleep 2.0
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
setup
mount_system && [ $? -eq 0 ] && backup_system_props && [ $? -eq 0 ] && change_system_props && [ $? -eq 0 ] && unmount_system
cleanup
