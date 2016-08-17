#!/bin/bash

EXEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXEC_DIR="${EXEC_DIR%/}"
ROOT_DIR="$(cd "${EXEC_DIR}/.." && pwd)"
ROOT_DIR="${ROOT_DIR%/}"
LOG_DIR="${ROOT_DIR}/logs"
LOG_FILE="AET.log"
source ${ROOT_DIR}/utilities.sh

USAGE="Usage: ./modify-ramdisk-img.sh [-b <backup directory> <backup file postfix>] <system image dir> <ramdisk directory> <modification file> [-s|--silent]"
HELP_TEXT="
OPTIONS
-b, --backup                Backups before making any modifications, use
                            this if you plan on reverting back at some
                            point
-d, --debug                 Debug mode, command output is logged to logs/AET.log
-s, --silent                Silent mode, suppresses all output except result
-h, --help                  Display this help and exit

<backup directory>          The directory where to store the backups
<backup file postfix>       A postfix after the backup filename
<system image directory>    Directory of the installed system image
<ramdisk directory>         Directory where the ramdisk file is being unzipped to
<modification file>         File with the modifications in key-value pairs"

SILENT_MODE=0
DEBUG_MODE=0

MODIFICATION_FILE=""
SYS_IMG_DIR=""
TMP_RAMDISK_DIR=""
BACKUP_DIR=""
BACKUP_POSTFIX=""

RAMDISK_FILE="ramdisk.img"
DEFAULT_PROP_FILE="default.prop"
MKBOOTFS_FILE="mkbootfs"

WHITESPACE_REGEX="^[[:blank:]]*$"
COMMENT_REGEX="^[[:blank:]]*#"
KEY_REGEX="^[[:blank:]]*\(.*\)=.*$"
VALUE_REGEX="^.*=\(.*\)$"

declare -A default_prop_changes=()

parse_arguments() {
    local show_help=0
    for ((i = 1; i <= $#; i++)); do
        if [ "${!i}" == "-h" ] || [ "${!i}" == "--help" ]; then
            show_help=1
        elif [ "${!i}" == "-s" ] || [ "${!i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ "${!i}" == "-d" ] || [ "${!i}" == "--debug" ]; then
            DEBUG_MODE=1
        elif [ "${!i}" == "-b" ] || [ "${!i}" == "--backup" ]; then
            for ((j = 0; j < 2; j++)); do
                argument_parameter_exists ${i} $@
                if [ $? -eq 1 ]; then
                    if [ ${j} == 0 ]; then
                        std_err "No backup directory given for '-b'!\n"
                    else
                        std_err "No backup postfix given for '-b'\n"
                    fi
                    std_err "${USAGE}"
                    std_err "See -h for more information"
                elif [ -z "${BACKUP_DIR}" ]; then
                    i=$((i + 1))
                    BACKUP_DIR="${!i}"
                    BACKUP_DIR="${BACKUP_DIR/\~/${HOME}}"
                    BACKUP_DIR="${BACKUP_DIR%/}"
                else
                    i=$((i + 1))
                    BACKUP_POSTFIX="${!i}"
                fi
            done
        elif [ -z "${SYS_IMG_DIR}" ]; then
            SYS_IMG_DIR="${!i}"
            SYS_IMG_DIR="${SYS_IMG_DIR/\~/${HOME}}"
            SYS_IMG_DIR="${SYS_IMG_DIR%/}"
        elif [ -z "${TMP_RAMDISK_DIR}" ]; then
            TMP_RAMDISK_DIR="${!i}"
            TMP_RAMDISK_DIR="${TMP_RAMDISK_DIR/\~/${HOME}}"
            TMP_RAMDISK_DIR="${TMP_RAMDISK_DIR%/}"
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
    || [ -z "${TMP_RAMDISK_DIR}" ] \
    || [ -z "${MODIFICATION_FILE}" ]; then
        std_err "${USAGE}"
        std_err "See -h for more information"
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
        std_err "Temporary ramdisk directory cannot be created!"
        exit 1
    fi

    if [ ! -f "${MODIFICATION_FILE}" ]; then
        std_err "Modification file does not exist!"
        exit 1
    fi

    if [ ! -z "${BACKUP_DIR}" ]; then
        mkdir -p ${BACKUP_DIR}
        if [ ! -d ${BACKUP_DIR} ]; then
            std_err "Could not create backup directory!"
            exit 1
        fi
    fi
} # parse_arguments()

setup() {
    local current_prop=""
    while read line; do
        if [ "${line}" == "@${DEFAULT_PROP_FILE}" ]; then
            current_prop="default_prop"
            continue
        elif [ "${line}" == "@*" ]; then
            current_prop=""
            continue
        fi

        [ "${current_prop}" == "default_prop" ] && parse_default_prop_change "${line}"
    done < "${MODIFICATION_FILE}"

    [ ${#default_prop_changes[@]} -eq 0 ] && println "WARNING: No changes to be made to ${DEFAULT_PROP_FILE}"
} # setup()

parse_default_prop_change() {
    local line="${1}"

    if [ $(expr "${line}" : "${COMMENT_REGEX}") -gt 0 ]; then
        return
    elif [ $(expr "${line}" : "${WHITESPACE_REGEX}") -gt 0 ]; then
        return
    elif [ -z "${line}" ]; then
        return
    fi

    local key_capture=$(expr "${line}" : "${KEY_REGEX}")
    local value_capture=$(expr "${line}" : "${VALUE_REGEX}")
    if [ ! -z "${key_capture}" ]; then
        default_prop_changes["${key_capture}"]="${value_capture}"
    else
        std_err "Unknown configuration found: ${line}"
        exit 1
    fi
} # parse_default_prop_change()

decompress_ramdisk() {
    local ret=0
    cd "${ROOT_DIR}/${TMP_RAMDISK_DIR}"
    gzip -dc "${SYS_IMG_DIR}/${RAMDISK_FILE}" | cpio -i &>/dev/null
    ret=$?

    cd ${ROOT_DIR}
    if [ ${ret} -eq 0 ]; then
        println "   [\033[0;32m OK \033[0m] Decompressing \033[1;35m${RAMDISK_FILE}\033[0m"
    else
        println "   [\033[0;31mFAIL\033[0m] Decompressing \033[1;35m${RAMDISK_FILE}\033[0m"
    fi
    return ${ret}
} # decompress_ramdisk()

backup_ramdisk_props() {
    local ret=0

    [ ! -z "${BACKUP_DIR}" ] || return 0

    if [ ! -f "${ROOT_DIR}/${TMP_RAMDISK_DIR}/${DEFAULT_PROP_FILE}" ]; then
        std_err "   \033[0;31m${DEFAULT_PROP_FILE} is missing or you do not have access!\033[0m"
        ret=1
    fi

    local backup_file="ramdisk${BACKUP_POSTFIX}"

    if [ ${ret} -eq 0 ]; then
        [ -f ${BACKUP_DIR}/${backup_file} ] && log "INFO" "$(rm ${BACKUP_DIR}/${backup_file} 2>&1)"
        
        printf "@${DEFAULT_PROP_FILE}\n" >> ${BACKUP_DIR}/${backup_file}
        while read line; do
            local key_capture=$(expr "${line}" : "${KEY_REGEX}")
            local value_capture=$(expr "${line}" : "${VALUE_REGEX}")
            if [ -z "${key_capture}" ]; then
                continue
            fi

            for key in ${!default_prop_changes[@]}; do
                if [ "${key}" == "${key_capture}" ]; then
                    printf "${key_capture}=${value_capture}\n" >> ${BACKUP_DIR}/${backup_file}
                    break
                fi
            done
        done < "${ROOT_DIR}/${TMP_RAMDISK_DIR}/${DEFAULT_PROP_FILE}"
    fi

    if [ ${ret} -eq 0 ]; then
        println "   [\033[0;32m OK \033[0m] Backing up"
    else
        println "   [\033[0;31mFAIL\033[0m] Backing up"
    fi

    return ${ret}
} # backup_ramdisk_props()

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
            local value=${default_prop_changes[${key}]}
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
    local output=$(rm -r "${ROOT_DIR}/${TMP_RAMDISK_DIR}" 2>&1)
    if [ $? -eq 0 ]; then
        println "   [\033[0;32m OK \033[0m] Cleanup"
    else
        println "   [\033[0;31mFAIL\033[0m] Cleanup"
    fi
    log "INFO" "${output}"
} # cleanup

parse_arguments $@
setup
decompress_ramdisk && [ $? -eq 0 ] && backup_ramdisk_props && [ $? -eq 0 ] && change_ramdisk_props && [ $? -eq 0 ] && compress_ramdisk
cleanup
