#!/bin/bash

DOWNLOAD_DIR=""
ASTUDIO_DIR=""
STUDIO_FILE=""

SPIN[0]="-"
SPIN[1]="\\"
SPIN[2]="|"
SPIN[3]="/"

parse_arguments() {
    if [ $# -ne 3 ]; then
        exit 1
    fi

    DOWNLOAD_DIR="$1"
    ASTUDIO_DIR="$2"
    STUDIO_FILE="$3"

    DOWNLOAD_DIR=${DOWNLOAD_DIR%/}
    ASTUDIO_DIR=${ASTUDIO_DIR%/}

    mkdir -p ${DOWNLOAD_DIR} &>/dev/null
    mkdir -p ${ASTUDIO_DIR} &>/dev/null
} # parse_arguments()

loading() {
    local message=${1}
    while true; do
        for s in "${SPIN[@]}"; do
            printf "\r$(tput el)"
            printf "%s" "[${message}] ${s}"
            sleep 0.1
        done
    done
} # loading()

install_android_studio() {
    printf "%s\n" "---------------------------------------"
    printf "%s\n" "Installing Android Studio"
    printf "%s\n" "---------------------------------------"
    download_android_studio
    if [ $? -ne 0 ]; then exit 1; fi
    unzip_android_studio
    if [ $? -ne 0 ]; then exit 1; fi
    printf "%s\n" ""
} # install_android_studio()

download_android_studio() {
    printf "%s\n" "Downloading Android Studio..."
    wget -q --show-progress -O "${DOWNLOAD_DIR}/${STUDIO_FILE}" "https://dl.google.com/dl/android/studio/ide-zips/2.1.1.0/android-studio-ide-143.2821654-linux.zip"
} # download_android_studio()

unzip_android_studio() {
    loading "Unzipping ${STUDIO_FILE}" &
    unzip "${DOWNLOAD_DIR}/${STUDIO_FILE}" -d "${ASTUDIO_DIR}" &>/dev/null
    kill $!
    trap 'kill $1' SIGTERM
    printf "\r$(tput el)"
    printf "%s\n" "[Unzipping ${STUDIO_FILE}] Done."
} # unzip_android_studio()

parse_arguments $@
install_android_studio
