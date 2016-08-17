#!/bin/bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="${ROOT_DIR%/}"
source ${ROOT_DIR}/utilities.sh

USAGE="Usage: ./wipe-tools.sh [-s|--silent] <configuration file>"
HELP_TEXT="
OPTIONS
-s, --silent            Silent mode, suppresses all output
-h, --help              Display this help and exit

<configuration file>    Configuration file for wipe-tools script"

BANNER="
========================================
>                                      <
>         Tools removal script         <
>       Author: Daniel Riissanen       <
>                                      <
========================================
"

SILENT_MODE=0
CONF_FILE=""

ASTUDIO_DIR=""
ASDK_DIR=""
AVD_DIR="${HOME}/.android/avd"

WHITESPACE_REGEX="^[[:blank:]]*$"
COMMENT_REGEX="^[[:blank:]]*\#"
A_STUDIO_REGEX="^android_studio_installation_dir[[:blank:]]*=[[:blank:]]*\(.*\)"
A_SDK_REGEX="^android_sdk_installation_dir[[:blank:]]*=[[:blank:]]*\(.*\)"
AVD_REGEX="^avd_dir[[:blank:]]*=[[:blank:]]*\(.*\)"

parse_arguments() {
    local show_help=0
    for i in $@; do
        if [ "${i}" == "-s" ] || [ "${i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ "${i}" == "-h" ] || [ "${i}" == "--help" ]; then
            show_help=1
        elif [ -z "${CONF_FILE}" ]; then
            CONF_FILE="${i}"
            CONF_FILE="${CONF_FILE/\~/${HOME}}"
            CONF_FILE="${CONF_FILE%/}"
        else
            std_err "Unknown argument: ${i}"
            std_err "${USAGE}"
            std_err "See -h for more information"
            exit 1
        fi
    done

    if [ ${show_help} -eq 1 ]; then
        print_help
        exit
    fi

    if [ -z "${CONF_FILE}" ]; then
        std_err "${USAGE}"
        std_err "See -h for more information"
        exit 1
    fi
} # parse_arguments()

read_conf() {
    if [ ! -f ${CONF_FILE} ]; then
        std_err "Wipe tools configuration file does not exits!"
        exit 1
    fi

    while read line; do
        if [ $(expr "${line}" : "${WHITESPACE_REGEX}") -gt 0 ]; then
            continue
        elif [ $(expr "${line}" : "${COMMENT_REGEX}") -gt 0 ]; then
            continue
        elif [ -z "${line}" ]; then
            continue
        fi

        local astudio_dir_capture=$(expr "${line}" : "${A_STUDIO_REGEX}")
        local asdk_dir_capture=$(expr "${line}" : "${A_SDK_REGEX}")
        local avd_dir_capture=$(expr "${line}" : "${AVD_REGEX}")

        if [ ! -z "${astudio_dir_capture}" ]; then
            ASTUDIO_DIR="${astudio_dir_capture}"
            ASTUDIO_DIR="${ASTUDIO_DIR/\~/${HOME}}"
            ASTUDIO_DIR="${ASTUDIO_DIR%/}"
        elif [ ! -z "${asdk_dir_capture}" ]; then
            ASDK_DIR="${asdk_dir_capture}"
            ASDK_DIR="${ASDK_DIR/\~/${HOME}}"
            ASDK_DIR="${ASDK_DIR%/}"
        elif [ ! -z "${avd_dir_capture}" ]; then
            AVD_DIR="${avd_dir_capture}"
            AVD_DIR="${AVD_DIR/\~/${HOME}}"
            AVD_DIR="${AVD_DIR%/}"
        fi
    done < "${CONF_FILE}"
} # read_conf()

wipe_tools() {
    println "${BANNER}"
    if [ ! -z "${ASTUDIO_DIR}" ] && [ -d ${ASTUDIO_DIR} ]; then
        rm -r ${ASTUDIO_DIR} &>/dev/null
        if [ $? -eq 0 ]; then
            println "[\033[0;32m OK \033[0m] Delete Android Studio"
        else
            println "[\033[0;31mFAIL\033[0m] Delete Android Studio"
        fi
    else
        println "Skipping Android Studio"
    fi

    if [ ! -z "${ASDK_DIR}" ] && [ -d ${ASDK_DIR} ]; then
        rm -r ${ASDK_DIR} &>/dev/null
        if [ $? -eq 0 ]; then
            println "[\033[0;32m OK \033[0m] Delete Android SDK"
        else
            println "[\033[0;31mFAIL\033[0m] Delete Android SDK"
        fi
    else
        println "Skipping Android SDK"
    fi

    if [ ! -z "${AVD_DIR}" ] && [ -d ${ASDK_DIR} ]; then
        rm -r ${AVD_DIR}/* &>/dev/null
        if [ $? -eq 0 ]; then
            println "[\033[0;32m OK \033[0m] Delete Android Virtual Devices"
        else
            println "[\033[0;31mFAIL\033[0m] Delete Android Virtual Devices"
        fi
    else
        println "Skipping Android Virtual Devices"
    fi
} # wipe_tools()

parse_arguments $@
read_conf
wipe_tools
