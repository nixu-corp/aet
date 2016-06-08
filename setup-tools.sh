#!/bin/bash

set -u

###################
# Global variables
###################

USAGE="Usage: ./setup-tools.sh <configuration file>"

ANDROID_SDK_SYS_IMG_BASE_URL="https://dl.google.com/android/repository/sys-img/android"
ANDROID_SDK_SYS_IMG_URL=""

CONF_FILE=""
ASTUDIO_DIR=""
ASDK_DIR=""
DOWNLOAD_DIR=""
STUDIO_FILE="android-studio"
SDK_FILE="android-sdk"
XML_FILE="sys-img.xml"
SYS_IMG_ZIP="sys-img.zip"
APIS=()
A_PLATFORMS=() 
G_PLATFORMS=()

# Configuration variables
WHITESPACE_REGEX="^[[:blank:]]*$"
COMMENT_REGEX="[[:blank:]]*\#"
DOWNLOAD_REGEX="^download_dir[[:blank:]]*=[[:blank:]]*(.*)"
A_STUDIO_REGEX="^android_studio_installation_dir[[:blank:]]*=[[:blank:]]*(.*)"
A_SDK_REGEX="^android_sdk_installation_dir[[:blank:]]*=[[:blank:]]*(.*)"
A_APIS_REGEX="^android_apis[[:blank:]]*=[[:blank:]]*(.*)"
A_PLATFORM_REGEX="^android_platform_architecture[[:blank:]]*=[[:blank:]]*(.*)"
G_PLATFORM_REGEX="^google_platform_architecture[[:blank:]]*=[[:blank:]]*(.*)"

SPIN[0]="-"
SPIN[1]="\\"
SPIN[2]="|"
SPIN[3]="/"


parse_arguments() {
    if [ $# -ne 1 ]; then
        echo ${USAGE}
        exit
    fi

    CONF_FILE=$1

    if [ ! -f ${CONF_FILE} ]; then
        echo "Configuration file does not exist!"
        exit
    fi
} # parse_arguments()

read_conf() {
    while read line; do
        if [[ $line =~ ${WHITESPACE_REGEX} ]]; then
            continue
        elif [[ $line =~ ${COMMENT_REGEX} ]]; then
            continue
        elif [[ $line =~ ${DOWNLOAD_REGEX} ]]; then
            DOWNLOAD_DIR="${BASH_REMATCH[1]}"
        elif [[ $line =~ ${A_STUDIO_REGEX} ]]; then
            ASTUDIO_DIR="${BASH_REMATCH[1]}"
        elif [[ $line =~ ${A_SDK_REGEX} ]]; then
            ASDK_DIR="${BASH_REMATCH[1]}"
        elif [[ $line =~ ${A_APIS_REGEX} ]]; then
            IFS=","
            read -r -a APIS <<< "${BASH_REMATCH[1]}"
        elif [[ $line =~ ${A_PLATFORM_REGEX} ]]; then
            IFS=","
            read -r -a A_PLATFORMS <<< "${BASH_REMATCH[1]}"
        
        fi
    done < "${CONF_FILE}"

    if [ ! -d "${DOWNLOAD_DIR}" ]; then
        echo "Download directory not found!"
        exit
    fi
} # read_conf()

check_filesystem() {
    DOWNLOAD_DIR="${DOWNLOAD_DIR%/}"

    local ext=".zip"
    local zip_postfix="0"
    while [ -f "${STUDIO_FILE}${ext}" ]; do
        STUDIO_FILE="${STUDIO_FILE}${zip_postfix}"
    done
    STUDIO_FILE="${STUDIO_FILE}${ext}"

    while [ -f "${SDK_FILE}${ext}" ]; do
        SDK_FILE="${SDK_FILE}${zip_postfix}"
    done
    SDK_FILE="${SDK_FILE}${ext}"

    local astudio_postfix="0"
    ASTUDIO_DIR="${ASTUDIO_DIR%/}"
    while [ -d ${ASTUDIO_DIR} ]; do
        ASTUDIO_DIR="${ASTUDIO_DIR}${astudio_postfix}"
    done
    mkdir -p "${ASTUDIO_DIR}"

    local asdk_postfix="-new"
    ASDK_DIR="${ASDK_DIR%/}"
    while [ -d ${ASDK_DIR} ]; do
        ASDK_DIR="${ASDK_DIR}${asdk_postfix}"
    done
    mkdir -p "${ASDK_DIR}"
} # check_filesystem()

download_android_studio() {
    echo "Downloading Android Studio..."
    wget -q --show-progress -O "${DOWNLOAD_DIR}/${STUDIO_FILE}" "https://dl.google.com/dl/android/studio/ide-zips/2.1.1.0/android-studio-ide-143.2821654-linux.zip"
} # download_android_studio()

unzip_android_studio() {
    while true; do
        for i in ${SPIN[@]}; do
            echo -ne "\r[Unzipping ${STUDIO_FILE}] $i"
            sleep 0.1
        done
    done & 
    unzip "${DOWNLOAD_DIR}/${STUDIO_FILE}" -d "${ASTUDIO_DIR}" &>/dev/null
    kill $!
    trap 'kill $1' SIGTERM
    echo -e "\r[Unzipping ${STUDIO_FILE}] Done."
} # unzip_android_studio()

download_android_sdk() {
    echo "Downloading Android SDK..."
    echo "${DOWNLOAD_DIR}/${SDK_FILE}"
    wget -q --show-progress -O "${DOWNLOAD_DIR}/${SDK_FILE}" "https://dl.google.com/android/android-sdk_r22.0.5-linux.tgz"
} # download_android_sdk()

unzip_android_sdk() {
    while true; do
        for i in ${SPIN[@]}; do
            echo -ne "\r[Unzipping ${SDK_FILE}] $i"
            sleep 0.1
        done
    done &
    tar -zxvf "${DOWNLOAD_DIR}/${SDK_FILE}" -C "${ASDK_DIR}" &>/dev/null
    kill $!
    trap 'kill $1' SIGTERM
    echo -e "\r[Unzipping ${SDK_FILE}] Done."
} # unzip_android_sdk

install_sdk_packages() {
    echo "Installing Android SDK packages..."

    local -a retry_packages=()
    local -a packages_info=()
    local package_ID=""
    local package_name=""
    local package_desc=""
    local previous_ID=""
    local previous_name=""
    local previous_desc=""
    local previous_count=0
    local -i round_done=0

    local grepstr=""
    local grepstr_bak=""
    local -i retry_count=1
    local -i retry_counter=0

    local -a packages
    packages[0]="platform-tools"
    packages[1]="tools"
    packages[2]="build-tools-"
    
    for sdk in ${APIS[@]}; do
        packages+=("${sdk}")
    done

    grepstr="^("
    for package in ${packages[@]}; do
        grepstr="${grepstr}${package}|"
    done
    grepstr=${grepstr%|}
    grepstr="${grepstr})"
    grepstr_bak=${grepstr}

    get_packages_info

    while [ ${#packages_info[@]} -gt 0 ]; do
        round_done=1
        for p in ${packages_info[@]}; do
            extract_package_info ${p}
            process_package_info ${grepstr}
            if [ $? -eq 0 ]; then round_done=0; fi
        done

        if [ ${round_done} -eq 1 ]; then
            if [ ${retry_counter} -lt ${retry_count} ] \
            && [ ${#retry_packages[@]} -gt 0 ]; then
                echo "----------------------------"
                echo "Retrying to install skipped packages"
                echo ${retry_packages[@]}
                packages_info=${retry_packages}
                retry_packages=()
                grepstr=${grepstr_bak}
                previous_ID=""
                previous_name=""
                previous_desc=""
                retry_counter=$((retry_counter + 1))
            else
                echo "Failed to install some packages"
                break
            fi
        else
            get_packages_info
        fi 
        
    done
    exit
} # install_sdk_packages()

get_packages_info() {
    local infogrep="(?s)id: \d+.*?Desc: .*?---"
    local package_data=$(${ASDK_DIR}/$(ls ${ASDK_DIR})/tools/android list sdk --extended 2>/dev/null | grep -Pzo ${infogrep}) &>/dev/null

    local package_info=""
    local regex="^---(id.*)"

    while read line; do
        if [[ ${line} =~ ${regex} ]]; then
            packages_info+=("${package_info}")   
            package_info=""
            package_info="${package_info}${BASH_REMATCH[1]}"
        else
            package_info="${package_info}${line}"
        fi
    done <<< "${package_data}"

    packages_info="$(echo ${packages_info} | sed "s/[[:blank:]]\+/ /g")"
} # get_package_info()

extract_package_info() {
    local id_regex="id: ([0-9]+)"
    local name_regex="or \"(.*?)\""
    local desc_regex="Desc: (.*[[:space:]].*)"
    package_ID=""
    package_name=""
    package_desc=""

    if [[ ${1} =~ ${id_regex} ]]; then
        package_ID="${BASH_REMATCH[1]}"
    fi

    if [[ ${1} =~ ${name_regex} ]]; then
        package_name="${BASH_REMATCH[1]}"
    fi

    if [[ ${1} =~ ${desc_regex} ]]; then
        package_desc="${BASH_REMATCH[1]}"
    fi
} # extract_package_info()

process_package_info() {
    local wanted_regex=${1}

    if ! [[ ${package_name} =~ ${wanted_regex} ]]; then
        return 1
    fi

    if [ "${previous_ID}" == "${package_ID}" ] \
    && [ "${previous_name}" == "${package_name}" ] \
    && [ "${previous_desc}" == "${package_desc}" ]; then
        previous_count=$((previous_count + 1))
    else
        previous_count=0
    fi

    if  [ ${previous_count} -ge 2 ]; then
        echo "Skipping ${package_desc}..."
        retry_packages+=("id: ${package_ID} or \"${package_name}\" Desc: ${package_desc}")
        grepstr=$(echo ${grepstr} | sed "s/${package_name}|\?//")
        grepstr="${grepstr%|)}"
        grepstr="${grepstr%)})"
    else
        install_package
    fi
} # process_package_info()

install_package() {
    echo "Installing ${package_desc} (\"${package_name}\")"
    (echo "y" | ${ASDK_DIR}/$(ls ${ASDK_DIR})/tools/android update sdk --no-ui --filter ${package_name}) &>/dev/null
    previous_ID=${package_ID}
    previous_name=${package_name}
    previous_desc=${package_desc}
} # install_package()

install_sdk_sys_imgs() {
    download_sys_img_xml
    parse_sys_img_xml
} # install_sdk_sys_imgs()

download_sys_img_xml() {
    wget -q --show-progress -O "${DOWNLOAD_DIR}/${XML_FILE}" "${ANDROID_SDK_SYS_IMG_BASE_URL}/sys-img.xml"
} # download_sys_img_xml()

parse_sys_img_xml() {
    local api_level="23"
    local platform="x86_64"
    local platform_n="y"

    if [ ${api_level} == "23" ] && [ ${platform_n} == "y" ]; then
        platform_n=" and x:codename"
    else
        platform_n=" and not(x:codename)"
    fi

    ANDROID_SDK_SYS_IMG_URL=$(xmlstarlet sel -N x=http://schemas.android.com/sdk/android/sys-img/3 -T -t -m "//x:system-image[x:api-level='${api_level}' and x:abi='${platform}' ${platform_n}]" -v "x:archives/x:archive/x:url" -n ${DOWNLOAD_DIR}/${XML_FILE})
} # parse_sys_img_xml()

download_sys_img() {
    wget -q --show-progress -O "${DOWNLOAD_DIR}/${SYS_IMG_ZIP}" "${ANDROID_SDK_SYS_IMG_BASE_URL}${ANDROID_SDK_SYS_IMG_URL}"
} # download_sys_img()

unzip_sys_img() {
    unzip "${DOWNLOAD_DIR}/${SYS_IMG_ZIP}" -d "${ASDK_DIR}/$(ls ${ASDK_DIR})/system-images/android-${API_LEVEL}/"
}

cleanup() {
    echo "Deleting files..."
    rm "${DOWNLOAD_DIR}/${STUDIO_FILE}" &>/dev/null
    rm "${DOWNLOAD_DIR}/${SDK_FILE}" &>/dev/null
    rm "${DOWNLOAD_DIR}/${XML_FILE}" &>/dev/null
} # cleanup()

parse_arguments $@
read_conf
check_filesystem
download_android_studio
download_android_sdk
unzip_android_studio
unzip_android_sdk
install_sdk_packages
download_sys_img_xml
parse_sys_img_xml
#download_sys_img
cleanup
echo -e "\nDone."
