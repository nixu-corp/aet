#!/bin/bash

set -u

EXEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXEC_DIR="${EXEC_DIR%/}"
ROOT_DIR="$(cd "${EXEC_DIR}/.." && pwd)"
source ${ROOT_DIR}/utilities.sh

USAGE="./run-env.h <android sdk directory> <avd name> [-s|--silent]"
HELP_TEXT="
OPTIONS
-s, --silent                Silent mode, suppresses all output except result
-h, --help                  Display this help and exit

<android sdk directory>     Android SDK installation directory
<avd name>                  Name of the Android Virtual Device to run"

ASDK_DIR=""
AVD_NAME=""

SILENT_MODE=0

parse_arguments() {
    if [ $# -lt 2 ]; then
        std_err "${USAGE}"
        std_err "See -h for more information"
        exit 1
    fi

    local show_help=0
    for ((i = 1; i <= $#; i++)); do
        if [ "${!i}" == "-h" ] || [ "${!i}" == "--help" ]; then
            show_help=1
        elif [ "${!i}" == "-s" ] || [ "${!i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ -z "${ASDK_DIR}" ]; then
            ASDK_DIR="${1%/}"
        elif [ -z "${AVD_NAME}" ]; then
            AVD_NAME="${2}"
        else
            std_err "Unknown argument: ${!i}"
            std_err "${USAGE}"
            std_err "See -h for more information"
            exit 1
        fi
    done

    if [ ${show_help} -eq 1 ]; then
        print_help
        exit 1
    fi

    if [ ! -d ${ASDK_DIR} ]; then
        std_err "Android SDK directory does not exist!"
        exit 1
    fi

    if [ ! -f ${ASDK_DIR}/$(ls ${ASDK_DIR})/tools/android ] \
    || [ ! -f ${ASDK_DIR}/$(ls ${ASDK_DIR})/platform-tools/adb ]; then
        std_err "Invalid Android SDK directory!"
        exit 1
    fi
} # parse_arguments()

check_avd() {
    local avd_name_grep=$(${ASDK_DIR}/$(ls ${ASDK_DIR})/tools/android list avd | grep "Name: ${AVD_NAME}$")

    if [ -z "${avd_name_grep}" ]; then
        std_err "There is no AVD with that name!"
        exit 1
    fi
} # check_avd()

run_emulator() {
#    ${ASDK_DIR}/$(ls ${ASDK_DIR})/platform-tools/adb start-server
#    ${ASDK_DIR}/$(ls ${ASDK_DIR})/tools/emulator -avd "${AVD_NAME}" -shell -verbose
    printf "Android SDK: ${ASDK_DIR}\n"
    printf "AVD Name: ${AVD_NAME}\n"
} # run_emulator()

parse_arguments $@
check_avd
run_emulator
