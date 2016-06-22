#!/bin/bash

SILENT_MODE=0

DOWNLOAD_DIR=""
ASDK_DIR=""

XML_FILE="sys-img"
SYS_IMG_FILE="sys-img"

ANDROID_SDK_SYS_IMG_BASE_URL="https://dl.google.com/android/repository/sys-img"
ANDROID_SDK_SYS_IMG_URL=""

A_PLATFORMS=()
G_PLATFORMS=()

SPIN[0]="-"
SPIN[1]="\\"
SPIN[2]="|"
SPIN[3]="/"

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
    
    if [ "$1" == "1" ]; then
        SILENT_MODE=1
        shift
    fi

    DOWNLOAD_DIR="$1"
    ASDK_DIR="$2"

    for ((i = 3; i <= $#; i++)); do
        if [ "${!i}" == "-a" ]; then
            i=$((i + 1))
            for ((j=${i}; j <= $#; j++)); do
                if [ "${!j}" == "-g" ]; then
                    i=$((j - 1))
                    break
                fi
                A_PLATFORMS+=("${!j}")
            done  
        elif [ "${!i}" == "-g" ]; then
            i=$((i + 1))
            for ((j = ${i}; j <= $#; j++)); do
                if [ "${!j}" == "-a" ]; then
                    i=$((j - 1))
                    break
                fi
                G_PLATFORMS+=("${!j}")
            done
        fi
    done

    if [ ! -d ${DOWNLOAD_DIR} ]; then
        printf "Download directory not found!\n"
        exit 1
    fi
} # parse_arguments()

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

parse_arguments $@
install_sdk_sys_imgs
