#!/bin/bash

set -u

EXEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXEC_DIR="${EXEC_DIR%/}"
source ${EXEC_DIR}/setup-utilities.sh
LOG_DIR="${ROOT_DIR}/logs"
LOG_FILE="AET.log"

USAGE="Usage: ./setup-tools.sh [-d|--debug] [-s|--silent] <configuration file>"
HELP_TEXT="
OPTIONS
-d, --debug                 Debug mode, command output is logged to logs/AET.log
-s, --silent            Silent mode, suppresses all output except result
-h, --help              Display this help and exit

<configuration file>    Configuration file for setup-tools script"

BANNER="
========================================
>                                      <
>          Tools setup script          <
>       Author: Daniel Riissanen       <
>                                      <
========================================
"
DEBUG_MODE=0
SILENT_MODE=0

ANDROID_SDK_SYS_IMG_BASE_URL="https://dl.google.com/android/repository/sys-img"
ANDROID_SDK_SYS_IMG_URL=""

CONF_FILE=""
ASTUDIO_DIR=""
ASDK_DIR=""
DOWNLOAD_DIR=""
STUDIO_FILE="android-studio-ide-143.2915827-linux.zip"
SDK_FILE="android-sdk_r22.0.5-linux.tgz"
TMP_A_APIS=("")
A_APIS=()
G_APIS=()
A_PLATFORMS=()
G_PLATFORMS=()
AVD_CONF_FILES=()

WHITESPACE_REGEX="^[[:blank:]]*$"
COMMENT_REGEX="^[[:blank:]]*\#"
DOWNLOAD_REGEX="^download_dir[[:blank:]]*=[[:blank:]]*\(.*\)"
A_STUDIO_REGEX="^android_studio_installation_dir[[:blank:]]*=[[:blank:]]*\(.*\)"
A_SDK_REGEX="^android_sdk_installation_dir[[:blank:]]*=[[:blank:]]*\(.*\)"
A_APIS_REGEX="^android_apis[[:blank:]]*=[[:blank:]]*\(.*\)"
G_APIS_REGEX="^google_apis[[:blank:]]*=[[:blank:]]*\(.*\)"
A_PLATFORM_REGEX="^android_platform_architecture[[:blank:]]*=[[:blank:]]*\(.*\)"
G_PLATFORM_REGEX="^google_platform_architecture[[:blank:]]*=[[:blank:]]*\(.*\)"
AVD_CONF_REGEX="^avd_configuration_files[[:blank:]]*=[[:blank:]]*\(.*\)"

parse_arguments() {
    local show_help=0
    for i in $@; do
        if [ "${i}" == "-s" ] || [ "${i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ "${i}" == "-h" ] || [ "${i}" == "--help" ]; then
            show_help=1
        elif [ "${i}" == "-d" ] || [ "${i}" == "--debug" ]; then
            DEBUG_MODE=1
        elif [ -z "${CONF_FILE}" ]; then
            CONF_FILE="${i}"
        else
            std_err "Unknown argument: ${i}"
            std_err "${USAGE}"
            std_err "See -h for more information"
            exit 1
        fi
    done

    if [ ${show_help} -eq 1 ]; then
        print_help
        exit
    fi

    if [ -z "${CONF_FILE}" ]; then
        std_err "${USAGE}"
        std_err "See -h for more information"
        exit 1
    fi
} # parse_arguments()

read_conf() {
    if [ ! -f ${CONF_FILE} ]; then
        std_err "Setup tools configuration file does not exist!"
        exit 1
    fi

    while read line; do
        local IFS=$'\t, '

        if [ $(expr "${line}" : "${WHITESPACE_REGEX}") -gt 0 ]; then
            continue
        elif [ $(expr "${line}" : "${COMMENT_REGEX}") -gt 0 ]; then
            continue
        elif [ -z "${line}" ]; then
            continue
        fi

        local download_dir_capture=$(expr "${line}" : "${DOWNLOAD_REGEX}")
        local astudio_dir_capture=$(expr "${line}" : "${A_STUDIO_REGEX}")
        local asdk_dir_capture=$(expr "${line}" : "${A_SDK_REGEX}")
        local a_apis_capture=$(expr "${line}" : "${A_APIS_REGEX}")
        local g_apis_capture=$(expr "${line}" : "${G_APIS_REGEX}")
        local a_platform_capture=$(expr "${line}" : "${A_PLATFORM_REGEX}")
        local g_platform_capture=$(expr "${line}" : "${G_PLATFORM_REGEX}")
        local avd_conf_capture=$(expr "${line}" : "${AVD_CONF_REGEX}")

        if [ ! -z "${download_dir_capture}" ]; then
            DOWNLOAD_DIR="${download_dir_capture}"
        elif [ ! -z "${astudio_dir_capture}" ]; then
            ASTUDIO_DIR="${astudio_dir_capture}"
        elif [ ! -z "${asdk_dir_capture}" ]; then
            ASDK_DIR="${asdk_dir_capture}"
        elif [ ! -z "${a_apis_capture}" ]; then
            read -r -a A_APIS <<< "${a_apis_capture}"
            A_APIS=("${A_APIS[@]/#/android-}")
        elif [ ! -z "${g_apis_capture}" ]; then
            read -r -a TMP_A_APIS <<< "${g_apis_capture}"
            TMP_A_APIS=("${TMP_A_APIS[@]/#/android-}")
            read -r -a G_APIS <<< "${g_apis_capture}"
            G_APIS=("${G_APIS[@]/#/addon-google_apis-google-}")
        elif [ ! -z "${a_platform_capture}" ]; then
            read -r -a A_PLATFORMS <<< "${a_platform_capture}"
        elif [ ! -z "${g_platform_capture}" ]; then
            read -r -a G_PLATFORMS <<< "${g_platform_capture}"
        elif [ ! -z "${avd_conf_capture}" ]; then
            read -r -a AVD_CONF_FILES <<< "${avd_conf_capture}"
        fi
    done < "${CONF_FILE}"

    for i in "${TMP_A_APIS[@]}"; do
        [ -z "${i}" ] || A_APIS+=("${i}")
    done

    if [ -z "${DOWNLOAD_DIR}" ]; then
        println "Download directory has not been specified!"
        exit 1
    fi
    if [ -z "${ASDK_DIR}" ]; then
        println "Android SDK directory has not been specified!"
        exit 1
    fi
} # read_conf()

check_filesystem() {
    DOWNLOAD_DIR="${DOWNLOAD_DIR%/}"
    ASTUDIO_DIR="${ASTUDIO_DIR%/}"
    ASDK_DIR="${ASDK_DIR%/}"

    if [ ! -d "${DOWNLOAD_DIR}" ]; then
        std_err "Download directory not found!"
        exit 1
    fi

    if [ -d "${ASTUDIO_DIR}" ]; then
        println "WARNING: Android studio installation directory already exists, will overwrite!"
    fi

    if [ -d "${ASDK_DIR}" ]; then
        println "WARNING: Android SDK installation directory already exists, will overwrite!"
    fi
} # check_filesystem()

##########################
# MAIN; Entry point
#########################
parse_arguments $@
read_conf
check_filesystem
println "${BANNER}"

modifiers=""
[ ${SILENT_MODE} -eq 1 ] && modifiers="${modifiers} --silent"
[ ${DEBUG_MODE} -eq 1 ] && modifiers="${modifiers} --debug"

${EXEC_DIR}/install-android-studio.sh ${DOWNLOAD_DIR} ${ASTUDIO_DIR} ${STUDIO_FILE} ${modifiers}
SKIP=$?

if [ ${SKIP} -eq 0 ]; then
    ${EXEC_DIR}/install-android-sdk.sh ${DOWNLOAD_DIR} ${ASDK_DIR} ${SDK_FILE} -a "${A_APIS[@]}" -g "${G_APIS[@]}" ${modifiers}
    SKIP=$?
else
    println "Skipping Android SDK installation"
fi

if [ ${SKIP} -eq 0 ]; then
    ${EXEC_DIR}/install-android-sys-imgs.sh ${DOWNLOAD_DIR} ${ASDK_DIR} -a "${A_PLATFORMS[@]}" -g "${G_PLATFORMS[@]}" ${modifiers}
    SKIP=$?
else
    println "Skipping system image installation"
fi

if [ ${SKIP} -eq 0 ]; then
    ${EXEC_DIR}/install-avds.sh ${ASDK_DIR} "${AVD_CONF_FILES[@]}" ${modifiers}
    SKIP=$?
else
    println "Skipping AVD installation"
fi
println ""
