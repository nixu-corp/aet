#!/bin/bash

set -u

EXEC_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"
EXEC_DIR="${EXEC_DIR%/}"
source ${EXEC_DIR}/setup-utilities.sh

USAGE="./install-android-sys-imgs.sh <download directory> <android sdk directory> [-a android platforms] [-g google platforms] [-s|--silent]"
HELP_TEXT="
OPTIONS
-a <android platforms>      Android platforms comma-separated in this format: <API>:<platform>
                            eg. '23:x86' for android-23, x86 cpu architecture
-g <google platforms>       Google platforms comma-separated in this format: <API>:<platform>
                            eg. '23:x86; for android-23, x86 cpu architecture
-s, --silent                Silent mode, suppresses all output except result
-h, --help                  Display this help and exit

<download directory>
<android sdk directory>     Android SDK installation directory"

DOWNLOAD_DIR=""
ASDK_DIR=""

XML_FILE="sys-img.xml"
SYS_IMG_FILE=""

ANDROID_SDK_SYS_IMG_BASE_URL="https://dl.google.com/android/repository/sys-img"
ANDROID_SDK_SYS_IMG_URL=""

A_PLATFORMS=()
G_PLATFORMS=()

parse_arguments() {
    if [ $# -eq 0 ]; then
        println "${USAGE}"
        println "See -h for more info"
        exit 1
    fi

    local show_help=0
    for ((i = 1; i <= $#; i++)); do
        if [ "${!i}" == "-s" ] || [ "${!i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ "${!i}" == "-h" ] || [ "${!i}" == "--help" ]; then
            show_help=1
        elif [ "${!i}" == "-a" ]; then
            i=$((i + 1))
            for ((j=${i}; j <= $#; j++)); do
                if [ $(expr "${!j}" : "--\?[[:alpha:]]") -ne 0 ]; then
                    i=$((j - 1))
                    break
                fi
                A_PLATFORMS+=("${!j}")
            done  
        elif [ "${!i}" == "-g" ]; then
            i=$((i + 1))
            for ((j = ${i}; j <= $#; j++)); do
                if [ $(expr "${!j}" : "--\?[[:alpha:]]") -ne 0 ]; then
                    i=$((j - 1))
                    break
                fi
                G_PLATFORMS+=("${!j}")
            done
        else
            if [ -z "${DOWNLOAD_DIR}" ]; then
                DOWNLOAD_DIR="${!i}"
            elif [ -z "${ASDK_DIR}" ]; then
                ASDK_DIR="${!i}"
            else
                println "Unknown argument: ${!i}"
                println "${USAGE}"
                println "See -h for more info"
                exit
            fi
        fi
    done

    if [ ${show_help} -eq 1 ]; then
        print_help
        exit
    fi

    if [ -z "${DOWNLOAD_DIR}" ] \
    || [ -z "${ASDK_DIR}" ]; then
        println "${USAGE}"
        println "See -h for more info"
        exit 1
    fi

    if [ ! -d ${ASDK_DIR} ]; then
        println "Android SDK directory does not exist!"
        exit 1
    fi

    if [ ${#A_PLATFORMS[@]} -eq 0 ] && [ ${#G_PLATFORMS[@]} -eq 0 ]; then
        println "No platforms have been specified!"
        exit 1
    fi

    mkdir -p ${DOWNLOAD_DIR} &>/dev/null
    if [ ! -d ${DOWNLOAD_DIR} ]; then
        println "Download directory does not exist!"
    fi
} # parse_arguments()

install_sdk_sys_imgs() {
    printfln "---------------------------------------"
    println "Installing Android SDK system images"
    printfln "---------------------------------------"
    clear_println ""
    clear_println  "Installing \033[1mAndroid API\033[0m system images"
    local tag_id=""

    if [ ${#A_PLATFORMS[@]} -gt 0 ]; then
        download_sys_img_xml "android"
        for platform in ${A_PLATFORMS[@]}; do
            local api="$(printf "${platform}" | cut -d ":" -f 1)"
            local plat="$(printf "${platform}" | cut -d ":" -f 2)"
            parse_sys_img_xml ${api} ${plat}

            download_file "${ANDROID_SDK_SYS_IMG_BASE_URL}/android/${SYS_IMG_FILE}" "${DOWNLOAD_DIR}" "${SYS_IMG_FILE}"
            if [ $? -ne 0 ]; then continue; fi
            check_downloaded_file "${DOWNLOAD_DIR}/${SYS_IMG_FILE}"
            if [ $? -ne 0 ]; then continue; fi
            unzip_file "${DOWNLOAD_DIR}" "${SYS_IMG_FILE}" "${ASDK_DIR}/$(ls ${ASDK_DIR})/system-images/android-${api}/${tag_id}/"
            if [ $? -ne 0 ]; then continue; fi
        done
        rm "${DOWNLOAD_DIR}/${XML_FILE}" &>/dev/null
    fi

    if [ ${#G_PLATFORMS[@]} -gt 0 ]; then
        clear_println ""
        clear_println "Installing \033[1mGoogle API\033[0m system images"
        download_sys_img_xml "google_apis"
        for platform in ${G_PLATFORMS[@]}; do
            local api="$(printf "${platform}" | cut -d ":" -f 1)"
            local plat="$(printf "${platform}" | cut -d ":" -f 2)"
            parse_sys_img_xml ${api} ${plat}

            download_file "${ANDROID_SDK_SYS_IMG_BASE_URL}/google_apis/${SYS_IMG_FILE}" "${DOWNLOAD_DIR}" "${SYS_IMG_FILE}"
            if [ $? -ne 0 ]; then continue; fi
            check_downloaded_file "${DOWNLOAD_DIR}/${SYS_IMG_FILE}"
            if [ $? -ne 0 ]; then continue; fi
            unzip_file "${DOWNLOAD_DIR}" "${SYS_IMG_FILE}" "${ASDK_DIR}/$(ls ${ASDK_DIR})/system-images/android-${api}/${tag_id}/"
            if [ $? -ne 0 ]; then continue; fi
        done
        rm "${DOWNLOAD_DIR}/${XML_FILE}" &>/dev/null
    fi
    clear_println ""
} # install_sdk_sys_imgs()

download_sys_img_xml() {
    local provider=${1}
    local progress_modifier="--show-progress"
    if [ "${SILENT_MODE}" == "1" ]; then
        progress_modifier=""
    fi

    println "Downloading: ${DOWNLOAD_DIR}/\033[1;35m${XML_FILE}\033[0m"
    wget -q ${progress_modifier} -O "${DOWNLOAD_DIR}/${XML_FILE}" "${ANDROID_SDK_SYS_IMG_BASE_URL}/${provider}/${XML_FILE}"
} # download_sys_img_xml()

parse_sys_img_xml() {
    local api_level="${1}"
    local platform="${2}"
    local platform_n=""

    if [ "${api_level}" == "23N" ]; then
        platform_n=" and x:codename"
    else
        platform_n=" and not(x:codename)"
    fi
    api_level=${api_level%N}

    if [ "${platform}" == "arm" ]; then
        platform="armeabi-v7a"
    fi

    local xmlstarlet_output=$(xmlstarlet sel -N x=http://schemas.android.com/sdk/android/sys-img/3 -T -t -m "//x:system-image[x:api-level='${api_level}' and x:abi='${platform}' ${platform_n}]" -v "concat(x:archives/x:archive/x:url, '|', x:tag-id )" -n ${DOWNLOAD_DIR}/${XML_FILE})

    SYS_IMG_FILE="$(printf "${xmlstarlet_output}" | cut -d "|" -f 1)"
    tag_id="$(printf "${xmlstarlet_output}" | cut -d "|" -f 2)"
} # parse_sys_img_xml()

parse_arguments $@
install_sdk_sys_imgs
