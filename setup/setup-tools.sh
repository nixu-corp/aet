#!/bin/bash

set -u

################################
# Outline
################################
# Global variables
#
# General functions
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
# Core Android SDK functions
#   install_android_sdk()
#   download_android_sdk()
#   unzip_android_sdk()
#   install_sdk_packages()
#   get_packages_info()
#   extract_package_info()
#   process_package_info()
#   install_package()
#
# Android SDK API's functions
#   install_sdk_sys_imgs()
#   download_sys_img_xml()
#   parse_sys_img_xml()
#   download_sys_img()
#   unzip_sys_img()
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

CONF_FILE=""
ASTUDIO_DIR=""
ASDK_DIR=""
DOWNLOAD_DIR=""
STUDIO_FILE="android-studio"
SDK_FILE="android-sdk"
XML_FILE="sys-img"
SYS_IMG_FILE="sys-img"
APIS=()
A_PLATFORMS=()
G_PLATFORMS=()

# Configuration variables
WHITESPACE_REGEX="^[[:blank:]]*$"
COMMENT_REGEX="^[[:blank:]]*\#"
DOWNLOAD_REGEX="^download_dir[[:blank:]]*=[[:blank:]]*\(.*\)"
A_STUDIO_REGEX="^android_studio_installation_dir[[:blank:]]*=[[:blank:]]*\(.*\)"
A_SDK_REGEX="^android_sdk_installation_dir[[:blank:]]*=[[:blank:]]*\(.*\)"
A_APIS_REGEX="^android_apis[[:blank:]]*=[[:blank:]]*\(.*\)"
A_PLATFORM_REGEX="^android_platform_architecture[[:blank:]]*=[[:blank:]]*\(.*\)"
G_PLATFORM_REGEX="^google_platform_architecture[[:blank:]]*=[[:blank:]]*\(.*\)"

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

write() {
    if [ ${SILENT_MODE} -eq 0 ]; then
        if [ $# -ge 2 ]; then
            printf "${1}" "${2}"
        elif [ $# -eq 1 ]; then
            printf "${1}"
        fi
    fi
} # message()

clear_print() {
    write "\r$(tput el)"
    write "${1}"
} # clear_print()

clear_println() {
    clear_print "${1}"
    write "\n"
} # clear_println()

clear_printf() {
    write "\r$(tput el)"
    write "%s" "${1}"
} # clear_printf()

clear_printfln() {
    clear_printf "${1}"
    write "\n"
} # clear_printfln()

parse_arguments() {
    if [ $# -eq 0 ] || [ $# -gt 2 ]; then
        clear_println "${USAGE}"
        clear_println "See -h for more info"
        exit
    fi

    for i in $@; do
        if [ "${i}" == "-s" ] || [ "${i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ "${i}" == "-h" ] || [ "${i}" == "--help" ]; then
            clear_println "${HELP_MSG}"
            exit
        else
            CONF_FILE="${i}"
        fi
    done

    if [ ! -f ${CONF_FILE} ]; then
        exit
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
        local a_platform_capture=$(expr "${line}" : "${A_PLATFORM_REGEX}")
        local g_platform_capture=$(expr "${line}" : "${G_PLATFORM_REGEX}")

        if [ ! -z "${download_dir_capture}" ]; then
            DOWNLOAD_DIR="${download_dir_capture}"
        elif [ ! -z "${astudio_dir_capture}" ]; then
            ASTUDIO_DIR="${astudio_dir_capture}"
        elif [ ! -z "${asdk_dir_capture}" ]; then
            ASDK_DIR="${asdk_dir_capture}"
        elif [ ! -z "${a_apis_capture}" ]; then
            IFS=","
            read -r -a APIS <<< "${a_apis_capture}"
        elif [ ! -z "${a_platform_capture}" ]; then
            IFS=","
            read -r -a A_PLATFORMS <<< "${a_platform_capture}"
        elif [ ! -z "${g_platform_capture}" ]; then
            IFS=","
            read -r -a G_PLATFORMS <<< "${g_platform_capture}"
        fi
    done < "${CONF_FILE}"
    
} # read_conf()

check_filesystem() {
    local zip_ext=".zip"
    local tgz_ext=".tgz"
    local xml_ext=".xml"
    local zip_postfix="0"
    local tgz_postfix="0"
    local xml_postfix="0"
    local astudio_postfix="-new"
    local asdk_postfix="-new"

    DOWNLOAD_DIR="${DOWNLOAD_DIR%/}"
    ASTUDIO_DIR="${ASTUDIO_DIR%/}"
    ASDK_DIR="${ASDK_DIR%/}"

    if [ ! -d "${DOWNLOAD_DIR}" ]; then
        clear_printfln "Download directory not found!"
        exit
    fi

    if [ -d "${ASTUDIO_DIR}" ]; then
        clear_printfln "WARNING: Android studio installation directory already exists, creating new one with postfix: '${astudio_postfix}'!"
    fi

    if [ -d "${ASDK_DIR}" ]; then
        clear_printfln "WARNING: Android SDK installation directory already exists, creating new one with postfix: '${asdk_postfix}'!"
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

    while [ -d ${ASTUDIO_DIR} ]; do
        ASTUDIO_DIR="${ASTUDIO_DIR}${astudio_postfix}"
    done

    while [ -d ${ASDK_DIR} ]; do
        ASDK_DIR="${ASDK_DIR}${asdk_postfix}"
    done
} # check_filesystem()

cleanup() {
    clear_printfln "Deleting files..."
    rm "${DOWNLOAD_DIR}/${STUDIO_FILE}" &>/dev/null
    rm "${DOWNLOAD_DIR}/${SDK_FILE}"  &>/dev/null
    rm "${DOWNLOAD_DIR}/${XML_FILE}"  &>/dev/null
    rm "${DOWNLOAD_DIR}/${SYS_IMG_FILE}" &>/dev/null
} # cleanup()

#############################
# Android SDK functions
#############################
install_sdk_sys_imgs() {
    clear_printfln "---------------------------------------"
    clear_printfln "Installing Android SDK system images"
    clear_printfln "---------------------------------------"
    clear_printfln ""
    clear_printfln "Installing Android API system images"
    local tag_id=""

    if [ ${#A_PLATFORMS[@]} -gt 0 ]; then
        download_sys_img_xml "android"
        for platform in ${A_PLATFORMS[@]}; do
            local api="$(printf "${platform}" | cut -d ":" -f 1)"
            local plat="$(printf "${platform}" | cut -d ":" -f 2)"
            parse_sys_img_xml ${api} ${plat}
            download_sys_img "android"
            unzip_sys_img ${api} ${plat} ${tag_id}
        done
    fi

    if [ ${#G_PLATFORMS[@]} -gt 0 ]; then
        clear_printfln ""
        clear_printfln "Installing Google API system images"
        download_sys_img_xml "google_apis"
        for platform in ${G_PLATFORMS[@]}; do
            local api="$(printf "${platform}" | cut -d ":" -f 1)"
            local plat="$(printf "${platform}" | cut -d ":" -f 2)"
            parse_sys_img_xml ${api} ${plat}
            download_sys_img "google_apis"
            unzip_sys_img ${api} ${plat} ${tag_id}
        done
    fi
    clear_printfln ""
} # install_sdk_sys_imgs()

download_sys_img_xml() {
    local provider=${1}

    wget -q --show-progress -O "${DOWNLOAD_DIR}/${XML_FILE}" "${ANDROID_SDK_SYS_IMG_BASE_URL}/${provider}/sys-img.xml"
} # download_sys_img_xml()

parse_sys_img_xml() {
    local api_level="$(printf "${1}" | cut -d "-" -f 2)"
    local platform="${2}"
    local platform_n=""

    if [ ${api_level} == "23N" ]; then
        platform_n=" and x:codename"
    else
        platform_n=" and not(x:codename)"
    fi
    api_level=${api_level%N}

    if [ "${platform}" == "arm" ]; then
        platform="armeabi-v7a"
    fi

    local xmlstarlet_output=$(xmlstarlet sel -N x=http://schemas.android.com/sdk/android/sys-img/3 -T -t -m "//x:system-image[x:api-level='${api_level}' and x:abi='${platform}' ${platform_n}]" -v "concat(x:archives/x:archive/x:url, '|', x:tag-id )" -n ${DOWNLOAD_DIR}/${XML_FILE})

    ANDROID_SDK_SYS_IMG_URL="$(printf "${xmlstarlet_output}" | cut -d "|" -f 1)"
    tag_id="$(printf "${xmlstarlet_output}" | cut -d "|" -f 2)"
} # parse_sys_img_xml()

download_sys_img() {
    local provider=${1}

    wget -q --show-progress -O "${DOWNLOAD_DIR}/${SYS_IMG_FILE}" "${ANDROID_SDK_SYS_IMG_BASE_URL}/${provider}/${ANDROID_SDK_SYS_IMG_URL}"
} # download_sys_img()

unzip_sys_img() {
    local api=${1}
    local platform=${2}
    local path="${ASDK_DIR}/$(ls ${ASDK_DIR})/system-images/${api}/${tag_id}/"

    loading "Unzipping ${SYS_IMG_FILE}" &
    mkdir -p ${path} &>/dev/null
    unzip "${DOWNLOAD_DIR}/${SYS_IMG_FILE}" -d ${path} &>/dev/null
    kill $!
    trap 'kill $1' SIGTERM
    clear_printfln "[Unzipping ${SYS_IMG_FILE}] Done."
} # unzip_sys_img()


##########################
# MAIN; Entry point
#########################
parse_arguments $@
read_conf
check_filesystem
clear_println "${BANNER}"
./install_android_studio.sh ${DOWNLOAD_DIR} ${ASTUDIO_DIR} ${STUDIO_FILE}
./install_android_sdk.sh ${DOWNLOAD_DIR} ${ASDK_DIR} ${SDK_FILE} ${APIS[@]}
install_sdk_sys_imgs
cleanup
clear_printfln "-----------------------------------"
clear_printfln "Done."
clear_printfln ""
