#!/bin/bash

set -u

################################
# Outline
################################
# Variables
#
# Functions
#   loading()
#   clear_print()
#   clear_println()
#   clear_printf()
#   clear_printfln()
#   parse_arguments()
#   read_conf()
#   check_filesystem()
#   cleanup()
#
# MAIN; Entry point
#
################################

###################
# Global variables
###################

EXEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source ${EXEC_DIR}/setup-utilities.sh

USAGE="Usage: ./setup-tools.sh [-s|--silent] <configuration file>"
HELP_TEXT="
OPTIONS
-s, --silent            Silent mode, suppresses all output except result
-h, --help              Display this help and exit

<configuration file>    Configuration file for setup-tools script"
HELP_MSG="${USAGE}\n${HELP_TEXT}"

BANNER="
========================================
>                                      <
>          Tools setup script          <
>       Author: Daniel Riissanen       <
>                                      <
========================================
"

ANDROID_SDK_SYS_IMG_BASE_URL="https://dl.google.com/android/repository/sys-img"
ANDROID_SDK_SYS_IMG_URL=""

CONF_FILE=""
ASTUDIO_DIR=""
ASDK_DIR=""
DOWNLOAD_DIR=""
STUDIO_FILE="android-studio-ide-143.2915827-linux.zip"
SDK_FILE="android-sdk_r22.0.5-linux.tgz"
XML_FILE="sys-img.xml"
SYS_IMG_FILE="sys-img.zip"
A_APIS=()
G_APIS=()
A_PLATFORMS=()
G_PLATFORMS=()
AVD_CONF_FILES=()

# Configuration variables
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

SILENT_MODE=0

#######################
# General functions
#######################

parse_arguments() {
    if [ $# -eq 0 ] || [ $# -gt 2 ]; then
        printf "${USAGE}\n"
        printf "See -h for more info\n"
        exit 1
    fi

    for i in $@; do
        if [ "${i}" == "-s" ] || [ "${i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ "${i}" == "-h" ] || [ "${i}" == "--help" ]; then
            printf "${HELP_MSG}\n"
            exit
        else
            CONF_FILE="${i}"
        fi
    done

    if [ ! -f ${CONF_FILE} ]; then
        exit 1
    fi
} # parse_arguments()

read_conf() {
    while read line; do

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
            IFS=","
            read -r -a A_APIS <<< "android-${a_apis_capture}"
        elif [ ! -z "${g_apis_capture}" ]; then
            IFS=","
            read -r -a G_APIS <<< "addon-google_apis-google-${g_apis_capture}"
        elif [ ! -z "${a_platform_capture}" ]; then
            IFS=","
            read -r -a A_PLATFORMS <<< "${a_platform_capture}"
        elif [ ! -z "${g_platform_capture}" ]; then
            IFS=","
            read -r -a G_PLATFORMS <<< "${g_platform_capture}"
        elif [ ! -z "${avd_conf_capture}" ]; then
            IFS=","
            read -r -a AVD_CONF_FILES <<< "${avd_conf_capture}"
        fi
    done < "${CONF_FILE}"

    if [ -z "${DOWNLOAD_DIR}" ]; then
        printf "Download directory has not been specified!\n"
        exit 1
    fi
    if [ -z "${ASDK_DIR}" ]; then
        printf "Android SDK directory has not been specified!\n"
        exit 1
    fi
} # read_conf()

check_filesystem() {
    DOWNLOAD_DIR="${DOWNLOAD_DIR%/}"
    ASTUDIO_DIR="${ASTUDIO_DIR%/}"
    ASDK_DIR="${ASDK_DIR%/}"

    if [ ! -d "${DOWNLOAD_DIR}" ]; then
        printf "Download directory not found!\n"
        exit 1
    fi

    if [ -d "${ASTUDIO_DIR}" ]; then
        printf "WARNING: Android studio installation directory already exists, will overwrite!\n"
    fi

    if [ -d "${ASDK_DIR}" ]; then
        printf "WARNING: Android SDK installation directory already exists, will overwrite!\n"
    fi
} # check_filesystem()

cleanup() {
    printf "\n"
    printf "%s\n" "---------------------------------------"
    printf "%s\n" "Cleanup"
    printf "%s\n" "---------------------------------------"
    printf "\n"
    printf "Deleting \033[1;35m${STUDIO_FILE}\033[0m\n"
    rm "${DOWNLOAD_DIR}/${STUDIO_FILE}" &>/dev/null
    printf "Deleting \033[1;35m${SDK_FILE}\033[0m\n"
    rm "${DOWNLOAD_DIR}/${SDK_FILE}"  &>/dev/null
    printf "Deleting \033[1;35m${XML_FILE}\033[0m\n"
    rm "${DOWNLOAD_DIR}/${XML_FILE}"  &>/dev/null
    printf "Deleting \033[1;35m${SYS_IMG_FILE}\033[0m\n"
    rm "${DOWNLOAD_DIR}/${SYS_IMG_FILE}" &>/dev/null
    printf "\n"
} # cleanup()

##########################
# MAIN; Entry point
#########################
parse_arguments $@
read_conf
check_filesystem
printf "${BANNER}\n"
${EXEC_DIR}/install-android-studio.sh ${DOWNLOAD_DIR} ${ASTUDIO_DIR} ${STUDIO_FILE}
SKIP=$?

if [ ${SKIP} -eq 0 ]; then
    ${EXEC_DIR}/install-android-sdk.sh ${DOWNLOAD_DIR} ${ASDK_DIR} ${SDK_FILE} -a "${A_APIS[@]}" -g "${G_APIS[@]}"
    SKIP=$?
else
    printf "Skipping Android SDK installation\n"
fi

if [ ${SKIP} -eq 0 ]; then
    ${EXEC_DIR}/install-android-sys-imgs.sh ${DOWNLOAD_DIR} ${ASDK_DIR} -a "${A_PLATFORMS[@]}" -g "${G_PLATFORMS[@]}"
    SKIP=$?
else
    printf "Skipping system image installation\n"
fi

if [ ${SKIP} -eq 0 ]; then
    ${EXEC_DIR}/install-avds.sh ${ASDK_DIR} "${AVD_CONF_FILES[@]}"
    SKIP=$?
else
    printf "Skipping AVD installation\n"
fi
cleanup
printf "%s\n" "-----------------------------------"
printf "Done.\n"
printf "\n"
