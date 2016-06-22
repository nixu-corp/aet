#!/bin/bash

USAGE="./install-avd.sh <Android SDK directory> <AVD configuration files>..."

EXEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$(dirname "${EXEC_DIR}")" && pwd)"
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

SPIN[0]="-"
SPIN[1]="\\"
SPIN[2]="|"
SPIN[3]="/"

loading() {
    local message=${1}
    while true; do
        for s in "${SPIN[@]}"; do
            printf "\r$(tput el)"
            printf "%s" "[${message}] ${s}"
            sleep 0.1
        done
    done
} # loading()

parse_arguments() {
    if [ $# -lt 1 ]; then
        printf "${USAGE}\n"
        exit 1
    fi

    EXEC_DIR=${EXEC_DIR%/}
    ROOT_DIR=${ROOT_DIR%/}

    ANDROID_SDK_DIR="$1"
    for ((i = 2; i <= $#; i++)); do
        AVD_CONF_FILES+=("${ROOT_DIR}/conf/${!i}")
    done

    if [ ! -d ${ANDROID_SDK_DIR} ]; then
        printf "The specified Android SDK directory does not exist!\n"
        exit 1
    fi

    if [ ${#AVD_CONF_FILES[@]} -eq 0 ]; then
        printf "No AVD configuration files specified!\n"
        exit 1
    fi
} # parse_arguments()

install_avds() {
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
        printf "AVD configuration file not found!\n"
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
        printf "AVD's name has not been specified!\n"
        return 1
    fi

    if [ -z "${AVD_TARGET}" ]; then
        printf "AVD's target has not been specified!\n"
        return 1
    fi

    if [ -z "${AVD_TAG}" ]; then
        printf "AVD's tag has not been specified!\n"
        return 1
    fi

    if [ -z "${AVD_ABI}" ]; then
        printf "AVD's abi has not been specified!\n"
        return 1
    fi
} # read_conf()

check_avd() {
    local avds=$(${ANDROID_SDK_DIR}/$(ls ${ANDROID_SDK_DIR})/tools/android list avd)
    if [ ! -z "$(printf "${avds}\n" | grep "Name: ${AVD_NAME}")" ]; then
        printf "There is already an AVD with the same name!\n"
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
        printf "AVD target is not valid, please check the configuration file\n"
        return 1
    fi

    if [ ${tag_abi_ok} -eq 0 ]; then
        printf "Tag/ABI combination not found, please check the configuration file\n"
        return 1
    fi
} # check_avd()

create_avd() {
    loading "Creating AVD \"${AVD_NAME}\"" &
    printf "\n" | ${ANDROID_SDK_DIR}/$(ls ${ANDROID_SDK_DIR})/tools/android create avd --name "${AVD_NAME}" --target "${AVD_TARGET}" --tag "${AVD_TAG}" --abi "${AVD_ABI}" &>/dev/null
    kill $!
    trap 'kill $1' SIGTERM
    printf "\r$(tput el)"

    printf "Created Android Virtual Device:\n"
    printf "  Name:       ${AVD_NAME}\n"
    printf "  Target:     ${AVD_TARGET}\n"
    printf "  Tag/ABIs:   ${AVD_TAG}/${AVD_ABI}\n"
    printf "\n"
} # create_avd()

printf "%s\n" "---------------------------------------"
printf "%s\n" "Installing AVD's"
printf "%s\n" "---------------------------------------"
printf "\n"
parse_arguments $@
install_avds
