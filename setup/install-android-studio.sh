#!/bin/bash

EXEC_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"
EXEC_DIR="${EXEC_DIR%/}"
source ${EXEC_DIR}/setup-utilities.sh

USAGE="./install-android-studio.sh <download directory> <Android Studio directory> <Android Studio zip file>... [-s|--silent]"

DOWNLOAD_DIR=""
ASTUDIO_DIR=""
STUDIO_FILE=""

parse_arguments() {
    if [ $# -lt 3 ]; then
        println "${USAGE}"
        exit 1
    fi

    DOWNLOAD_DIR="$1"
    ASTUDIO_DIR="$2"
    STUDIO_FILE="$3"

    if [ "$4" == "-s" ] || [ "$4" == "--silent" ]; then
        SILENT_MODE=1
    fi

    DOWNLOAD_DIR=${DOWNLOAD_DIR%/}
    ASTUDIO_DIR=${ASTUDIO_DIR%/}

    mkdir -p ${DOWNLOAD_DIR} &>/dev/null
    mkdir -p ${ASTUDIO_DIR} &>/dev/null
} # parse_arguments()

install_android_studio() {
    printfln "---------------------------------------"
    println "Installing Android Studio"
    printfln "---------------------------------------"
    download_file "https://dl.google.com/dl/android/studio/ide-zips/2.1.2.0/${STUDIO_FILE}" "${DOWNLOAD_DIR}" "${STUDIO_FILE}"
    if [ $? -ne 0 ]; then exit 1; fi
    check_downloaded_file "${DOWNLOAD_DIR}/${STUDIO_FILE}"
    if [ $? -ne 0 ]; then exit 1; fi
    unzip_file "${DOWNLOAD_DIR}" "${STUDIO_FILE}" "${ASTUDIO_DIR}"
    if [ $? -ne 0 ]; then exit 1; fi
    println ""
} # install_android_studio()

parse_arguments $@
install_android_studio
