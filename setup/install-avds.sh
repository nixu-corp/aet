#!/bin/bash

EXEC_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"
EXEC_DIR="${EXEC_DIR%/}"
source ${EXEC_DIR}/setup-utilities.sh
LOG_DIR="${ROOT_DIR}/logs"
LOG_FILE="AET.log"

USAGE="Usage: ./install-avd.sh <android sdk directory> <avd configuration files> [-d|--debug] [-s|--silent]"
HELP_TEXT="
OPTIONS
-d, --debug                 Debug mode, command output is logged to logs/AET.log
-s, --silent                Silent mode, suppresses all output except result
-h, --help                  Display this help and exit

<android sdk directory>     Android SDK installation directory
<avd configuration files>   AVD configuration files, each one as a separate argument"

DEBUG_MODE=0
SILENT_MODE=0

ANDROID_SDK_DIR=""
AVD_CONF_FILES=()
AVD_TARGET=""
AVD_NAME=""
AVD_TAG=""
AVD_ABI=""

WHITESPACE_REGEX="^[[:blank:]]*$"
COMMENT_REGEX="^[[:blank:]]*\#"
NAME_REGEX="^name[[:blank:]]*=[[:blank:]]*\(.*\)"
TARGET_REGEX="^target[[:blank:]]*=[[:blank:]]*\(.*\)"
TAG_REGEX="^tag[[:blank:]]*=[[:blank:]]*\(.*\)"
ABI_REGEX="^abi[[:blank:]]*=[[:blank:]]*\(.*\)"

parse_arguments() {
    local show_help=0
    for ((i = 1; i <= $#; i++)); do
        if [ "${!i}" == "-s" ] || [ "${!i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ "${!i}" == "-h" ] || [ "${!i}" == "--help" ]; then
            show_help=1
        elif [ "${!i}" == "-d" ] || [ "${!i}" == "--debug" ]; then
            DEBUG_MODE=1
        elif [ -z "${ANDROID_SDK_DIR}" ]; then
            ANDROID_SDK_DIR="${!i/\~/${HOME}}"
        else
            AVD_CONF_FILES+=("${ROOT_DIR}/conf/${!i}")
        fi
    done

    if [ ${show_help} -eq 1 ]; then
        print_help
        exit
    fi

    if [ -z "${ANDROID_SDK_DIR}" ]; then
        std_err "${USAGE}"
        std_err "See -h for more information"
        exit 1
    fi

    if [ ! -d ${ANDROID_SDK_DIR} ]; then
        std_err "Android SDK directory does not exist!"
        exit 1
    fi

    if [ ${#AVD_CONF_FILES[@]} -eq 0 ]; then
        std_err "No AVD configuration files have been specified!"
        exit 1
    fi
} # parse_arguments()

install_avds() {
    printfln "---------------------------------------"
    println "Installing AVD's"
    printfln "---------------------------------------"

    for avd_conf in ${AVD_CONF_FILES[@]}; do
        AVD_NAME=""
        AVD_TARGET=""
        AVD_TAG=""
        AVD_ABI=""

        read_conf ${avd_conf}
        [ $? -eq 0 ] || continue
        check_avd
        [ $? -eq 0 ] || continue
        create_avd
    done
} # install_avds()

read_conf() {
    local conf_file="$1"
    if [ ! -f ${conf_file} ]; then
        std_err "AVD configuration file not found!"
        return 1
    fi

    while read line; do
        if [ $(expr "${line}" : "${WHITESPACE_REGEX}") -gt 0 ]; then
            continue
        elif [ $(expr "${line}" : "${COMMENT_REGEX}") -gt 0 ]; then
            continue
        elif [ -z "${line}" ]; then
            continue
        fi

        local name_capture=$(expr "${line}" : "${NAME_REGEX}")
        local target_capture=$(expr "${line}" : "${TARGET_REGEX}")
        local tag_capture=$(expr "${line}" : "${TAG_REGEX}")
        local abi_capture=$(expr "${line}" : "${ABI_REGEX}")

        if [ ! -z "${name_capture}" ]; then
            AVD_NAME="${name_capture}"
        elif [ ! -z "${target_capture}" ]; then
            AVD_TARGET="${target_capture}"
        elif [ ! -z "${tag_capture}" ]; then
            AVD_TAG="${tag_capture}"
        elif [ ! -z "${abi_capture}" ]; then
            AVD_ABI="${abi_capture}"
        fi
    done < "${conf_file}"

    if [ "${AVD_TAG}" == "google_apis" ]; then
        AVD_TARGET="Google Inc.:Google APIs:${AVD_TARGET}"
    else
        AVD_TARGET="android-${AVD_TARGET}"
    fi

    if [ -z "${AVD_NAME}" ]; then
        std_err "AVD's name has not been specified!"
        return 1
    fi

    if [ -z "${AVD_TARGET}" ]; then
        std_err "AVD's target has not been specified!"
        return 1
    fi

    if [ -z "${AVD_TAG}" ]; then
        std_err "AVD's tag has not been specified!"
        return 1
    fi

    if [ -z "${AVD_ABI}" ]; then
        std_err "AVD's abi has not been specified!"
        return 1
    fi
} # read_conf()

check_avd() {
    local avds=$(${ANDROID_SDK_DIR}/$(ls ${ANDROID_SDK_DIR})/tools/android list avd)
    if [ ! -z "$(printf "${avds}\n" | grep "Name: ${AVD_NAME}")" ]; then
        std_err "There is already an AVD with the same name!"
        return 1
    fi

    local targets=$(${ANDROID_SDK_DIR}/$(ls ${ANDROID_SDK_DIR})/tools/android list targets)
    local name_regex="\(Name: .*\)"
    local id_regex="\(id: [[:digit:]][[:digit:]]\? or \"${AVD_TARGET}\"\)"
    local tag_abi_regex="\(Tag/ABIs : ${AVD_TAG}/${AVD_ABI}\)"
    local target_ok=0
    local tag_abi_ok=0
    
    while read line; do
        local id_capture=$(expr "${line}" : "${id_regex}")
        local tag_abi_capture=$(expr "${line}" : "${tag_abi_regex}")

        if [ ! -z "${id_capture}" ]; then
            target_ok=1 
        elif [ ! -z "${tag_abi_capture}" ]; then
            tag_abi_ok=1
        fi
    done <<< "${targets}"

    if [ ${target_ok} -eq 0 ]; then
        std_err "AVD target is not valid, please check the configuration file"
        return 1
    fi

    if [ ${tag_abi_ok} -eq 0 ]; then
        std_err "Tag/ABI combination not found, please check the configuration file"
        return 1
    fi
} # check_avd()

create_avd() {
    loading "Creating AVD \"${AVD_NAME}\"" &
    log "INFO" "$(printf "\n\n" | ${ANDROID_SDK_DIR}/$(ls ${ANDROID_SDK_DIR})/tools/android create avd --name "${AVD_NAME}" --target "${AVD_TARGET}" --tag "${AVD_TAG}" --abi "${AVD_ABI}" 2>&1)"
    kill $!
    trap 'kill $1' SIGTERM
    clear_println ""

    println "Created Android Virtual Device:"
    println "  Name:       ${AVD_NAME}"
    println "  Target:     ${AVD_TARGET}"
    println "  Tag/ABIs:   ${AVD_TAG}/${AVD_ABI}"
    println ""
} # create_avd()

parse_arguments $@
install_avds
