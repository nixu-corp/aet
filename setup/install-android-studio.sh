#!/bin/bash

EXEC_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"
source ${EXEC_DIR}/setup-utilities.sh

DOWNLOAD_DIR=""
ASTUDIO_DIR=""
STUDIO_FILE=""

parse_arguments() {
    if [ $# -ne 3 ]; then
        exit 1
    fi

    DOWNLOAD_DIR="$1"
    ASTUDIO_DIR="$2"
    STUDIO_FILE="$3"

    DOWNLOAD_DIR=${DOWNLOAD_DIR%/}
    ASTUDIO_DIR=${ASTUDIO_DIR%/}

    if [ ! -d ${DOWNLOAD_DIR} ]; then
        printf "Download directory not found!\n"
        exit
    fi

    mkdir -p ${ASTUDIO_DIR} &>/dev/null
} # parse_arguments()

install_android_studio() {
    printf "%s\n" "---------------------------------------"
    printf "%s\n" "Installing Android Studio"
    printf "%s\n" "---------------------------------------"
    download_file "https://dl.google.com/dl/android/studio/ide-zips/2.1.2.0/${STUDIO_FILE}" "${DOWNLOAD_DIR}" "${STUDIO_FILE}"
    if [ $? -ne 0 ]; then exit 1; fi
    check_downloaded_file "${DOWNLOAD_DIR}/${STUDIO_FILE}"
    if [ $? -ne 0 ]; then exit 1; fi
    unzip_file "${DOWNLOAD_DIR}" "${STUDIO_FILE}" "${ASTUDIO_DIR}"
    if [ $? -ne 0 ]; then exit 1; fi
    printf "%s\n" ""
} # install_android_studio()

parse_arguments $@
install_android_studio
