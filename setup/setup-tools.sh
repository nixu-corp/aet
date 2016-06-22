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

EXEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE=""
ASTUDIO_DIR=""
ASDK_DIR=""
DOWNLOAD_DIR=""
STUDIO_FILE="android-studio"
SDK_FILE="android-sdk"
XML_FILE="sys-img"
SYS_IMG_FILE="sys-img"
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

SPIN[0]="-"
SPIN[1]="\\"
SPIN[2]="|"
SPIN[3]="/"

#######################
# General functions
#######################

loading() {
    local message=${1}
    while true; do
        for s in "${SPIN[@]}"; do
            clear_printf "[${message}] ${s}"
            sleep 0.1
        done
    done
} # loading()

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
    local zip_ext=".zip"
    local tgz_ext=".tgz"
    local xml_ext=".xml"
    local zip_postfix="0"
    local tgz_postfix="0"
    local xml_postfix="0"

    DOWNLOAD_DIR="${DOWNLOAD_DIR%/}"
    ASTUDIO_DIR="${ASTUDIO_DIR%/}"
    ASDK_DIR="${ASDK_DIR%/}"

    if [ ! -d "${DOWNLOAD_DIR}" ]; then
        printf "Download directory not found!\n"
        exit 1
    fi

    if [ -d "${ASTUDIO_DIR}" ]; then
        printf "WARNING: Android studio installation directory already exists, creating new one with postfix: '${astudio_postfix}'!\n"
    fi

    if [ -d "${ASDK_DIR}" ]; then
        printf "WARNING: Android SDK installation directory already exists, creating new one with postfix: '${asdk_postfix}'!\n"
    fi

    while [ -f "${DOWNLOAD_DIR}/${STUDIO_FILE}${zip_ext}" ]; do
        STUDIO_FILE="${STUDIO_FILE}${zip_postfix}"
    done
    STUDIO_FILE="${STUDIO_FILE}${zip_ext}"

    while [ -f "${DOWNLOAD_DIR}/${SYS_IMG_FILE}${zip_ext}" ]; do
        SYS_IMG_FILE="${SYS_IMG_FILE}${zip_postfix}"
    done
    SYS_IMG_FILE="${SYS_IMG_FILE}${zip_ext}"

    while [ -f "${DOWNLOAD_DIR}/${SDK_FILE}${tgz_ext}" ]; do
        SDK_FILE="${SDK_FILE}${tgz_postfix}"
    done
    SDK_FILE="${SDK_FILE}${tgz_ext}"

    while [ -f "${DOWNLOAD_DIR}/${XML_FILE}${xml_ext}" ]; do
        XML_FILE="${XML_FILE}${xml_postfix}"
    done
    XML_FILE="${XML_FILE}${xml_ext}"
} # check_filesystem()

cleanup() {
    printf "\n"
    printf "%s\n" "---------------------------------------"
    printf "%s\n" "Cleanup"
    printf "%s\n" "---------------------------------------"
    printf "\n"
    printf "Deleting ${STUDIO_FILE}\n"
    rm "${DOWNLOAD_DIR}/${STUDIO_FILE}" &>/dev/null
    printf "Deleting ${SDK_FILE}\n"
    rm "${DOWNLOAD_DIR}/${SDK_FILE}"  &>/dev/null
    printf "Deleting ${XML_FILE}\n"
    rm "${DOWNLOAD_DIR}/${XML_FILE}"  &>/dev/null
    printf "Deleting ${SYS_IMG_FILE}\n"
    rm "${DOWNLOAD_DIR}/${SYS_IMG_FILE}" &>/dev/null
} # cleanup()

##########################
# MAIN; Entry point
#########################
parse_arguments $@
read_conf
check_filesystem
printf "${BANNER}\n"
${EXEC_DIR}/install-android-studio.sh ${DOWNLOAD_DIR} ${ASTUDIO_DIR} ${STUDIO_FILE}
${EXEC_DIR}/install-android-sdk.sh ${DOWNLOAD_DIR} ${ASDK_DIR} ${SDK_FILE} -a "${A_APIS[@]}" -g "${G_APIS[@]}"
${EXEC_DIR}/install-android-sys-imgs.sh ${DOWNLOAD_DIR} ${ASDK_DIR} -a "${A_PLATFORMS[@]}" -g "${G_PLATFORMS[@]}"
${EXEC_DIR}/install-avds.sh ${ASDK_DIR} "${AVD_CONF_FILES[@]}"
cleanup
printf "%s\n" "-----------------------------------"
printf "Done.\n"
printf "\n"
