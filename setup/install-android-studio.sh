#!/bin/bash

EXEC_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"
EXEC_DIR="${EXEC_DIR%/}"
source ${EXEC_DIR}/setup-utilities.sh

USAGE="./install-android-studio.sh <download directory> <android studio directory> <android studio zip file> [-s|--silent]"
HELP_TEXT="
OPTIONS
-s, --silent                Silent mode, suppresses all output except result
-h, --help                  Display this help and exit

<download directory>
<android studio directory>  Android Studio installation directory
<android studio zip file>   The android studio download file name"

DOWNLOAD_DIR=""
ASTUDIO_DIR=""
STUDIO_FILE=""

parse_arguments() {
    if [ $# -eq 0 ]; then
        println "${USAGE}"
        println "See -h for more info"
        exit 1
    fi

    show_help=0
    for arg in $@; do
        if [ "${arg}" == "-h" ] || [ "${arg}" == "--help" ]; then
            show_help=1
        elif [ "${arg}" == "-s" ] || [ "${arg}" == "--silent" ]; then
            SILENT_MODE=1
        else
            if [ -z "${DOWNLOAD_DIR}" ]; then
                DOWNLOAD_DIR="${arg}"
            elif [ -z "${ASTUDIO_DIR}" ]; then
                ASTUDIO_DIR="${arg}"
            elif [ -z "${STUDIO_FILE}" ]; then
                STUDIO_FILE="${arg}"
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
    || [ -z "${ASTUDIO_DIR}" ] \
    || [ -z "${STUDIO_FILE}" ]; then
        println "${USAGE}"
        println "See -h for more info"
        exit 1
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
