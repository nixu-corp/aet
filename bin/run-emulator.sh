#!/bin/bash

set -u

EXEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXEC_DIR="${EXEC_DIR%/}"
ROOT_DIR="$(cd "${EXEC_DIR}/.." && pwd)"
ROOT_DIR="${ROOT_DIR%/}"
LOG_DIR="${ROOT_DIR}/logs"
LOG_FILE="AET.log"
source ${ROOT_DIR}/emulator-utilities.sh

USAGE="./run-emulator.sh <android sdk directory> <avd name> [-c|--clear] [-d|--debug] [-s|--silent]"
HELP_TEXT="
OPTIONS
-c, --clear                 Wipe user data before booting emulator
-d, --debug                 Debug mode, command output is logged to logs/AET.log
-s, --silent                Silent mode, suppresses all output except result
-h, --help                  Display this help and exit

<android sdk directory>     Android SDK installation directory
<avd name>                  Name of the Android Virtual Device to run"

ASDK_DIR=""
AVD_NAME=""
CLEAR_DATA=""

SILENT_MODE=0
DEBUG_MODE=0

parse_arguments() {
    if [ $# -eq 0 ]; then
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
        elif [ "${!i}" == "-c" ] || [ "${!i}" == "--clear" ]; then
            CLEAR_DATA="-wipe-data"
        elif [ "${!i}" == "-d" ] || [ "${!i}" == "--debug" ]; then
            DEBUG_MODE=1
        elif [ -z "${ASDK_DIR}" ]; then
            ASDK_DIR="${!i/~/${HOME}}"
            ASDK_DIR="${ASDK_DIR%/}"
        elif [ -z "${AVD_NAME}" ]; then
            AVD_NAME="${!i}"
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

    if [ -z "${ASDK_DIR}" ]; then
        std_err "${USAGE}"
        std_err "See -h for more information"
        std_err "Android SDK has not been specified!"
        exit 1
    fi

    if [ -z "${AVD_NAME}" ]; then
        std_err "${USAGE}"
        std_err "See -h for more information"
        std_err "AVD name has not been specified!"
        exit 1
    fi
} # parse_arguments()

check_files() {
    if [ ! -d ${ASDK_DIR} ]; then
        std_err "Android SDK directory does not exist!"
        exit 1
    fi

    if [ ! -f ${ASDK_DIR}/$(ls ${ASDK_DIR})/tools/android ]; then
        std_err "${ASDK_DIR}/$(ls ${ASDK_DIR})/tools/android is missing!"
        exit 1
    fi

    if [ ! -f ${ASDK_DIR}/$(ls ${ASDK_DIR})/platform-tools/adb ]; then
        std_err "${ASDK_DIR}/$(ls ${ASDK_DIR})/platform-tools/adb is missing!"
        exit 1
    fi
} # check_files()


parse_arguments $@
check_files
check_avd ${AVD_NAME}
emulator_is_running
if [ $? -eq 0 ]; then
    std_err "Emulator is already running!"
    exit 1
fi
start_avd ${AVD_NAME} ${CLEAR_DATA}
wait_for_device

if [ $? -eq 0 ]; then
    println "AVD is running"
else
    log "DEBUG" "$(${ASDK_DIR}/$(ls ${ASDK_DIR})/platform-tools/adb emu kill 2>&1)"
    std_err "Failed to start emulator!"
    exit 1
fi
