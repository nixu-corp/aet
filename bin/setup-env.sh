#!/bin/bash

set -u

EXEC_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"
EXEC_DIR="${EXEC_DIR%/}"
ROOT_DIR="$(cd "${EXEC_DIR}/.." && pwd)"
ROOT_DIR="${ROOT_DIR%/}"
source ${ROOT_DIR}/emulator-utilities.sh

USAGE="Usage: ./setup-env.sh [-b|--backup] [-s|--silent] [-w|--wipe] [-c <configuration file>] [-e <configuration file>] [-r <configuration file>]"
HELP_TEXT="
OPTIONS
-b, --backup                Enable backup for modification scripts
-c, --create                Installs the environment and the necessary tools
    <configuration file>    OPTIONAL: Configuration file for environment
                            setup
                                default: conf/setup-tools.conf

-e, --emulator              Modifies the environment to evade emulation detection
                            OPTIONAL: Configuration file for emulation detection
                            evasion
                                default: conf/emulation-detection-evasion.conf

-r, --root                  Modifier the environment to evade root detection
                            OPTIONAL: Configuration file for root detection
                            evasion
                                default: conf/root-detection-evasion.conf

-w, --wipe                  Wipe mode, will clean up installed files. if used in
                            combination with -c or --create it will work as a
                            clean reinstall
-s, --silent                Silent mode, suppresses all output except result
-h, --help                  Display this help and exit"

HELP_MSG="${USAGE}\n${HELP_TEXT}"

ROOT=0
WIPE=0
SETUP_TOOLS=0
EMULATOR_ENV=0
ROOT_ENV=0
DO_BACKUP=0

ROOT_PASSWORD=""
WIPE_CONF="conf/wipe-tools.conf"
TOOLS_CONF="conf/setup-tools.conf"
EMULATOR_CONF="conf/emulation-detection-evasion.conf"
ROOT_CONF="conf/root-detection-evasion.conf"

check_dependencies() {
    local ret=0
    if [ -z "$(which java)" ]; then
        ret=1
        std_err "Dependency missing: Java"
    fi

    if [ -z "$(which xmlstarlet)" ]; then
        ret=1
        std_err "Dependency missing: XMLStarlet"
    fi

    [ ${ret} -eq 0 ] || exit 1
} # check_dependencies()

parse_arguments() {
    local show_help=0
    for ((i=1; i <= $#; i++)); do
        if [ "${!i}" == "-s" ] || [ "${!i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ "${!i}" == "-h" ] || [ "${!i}" == "--help" ]; then
            show_help=1
        elif [ "${!i}" == "-b" ] || [ "${!i}" == "--backup" ]; then
            DO_BACKUP=1
        elif [ "${!i}" == "-w" ] || [ "${!i}" == "--wipe" ]; then
            WIPE=1
            argument_parameter_exists ${i} $@
            if [ $? -eq 0 ]; then
                WIPE_CONF="${!i}"
                i=$((i + 1))
            fi
        elif [ "${!i}" == "-c" ] || [ "${!i}" == "--create" ]; then
            SETUP_TOOLS=1
            argument_parameter_exists ${i} $@
            if [ $? -eq 0 ]; then
                TOOLS_CONF="${!i}"
                i=$((i + 1))
            fi
        elif [ "${!i}" == "-e" ] || [ "${!i}" == "--emulator" ]; then
            EMULATOR_ENV=1
            argument_parameter_exists ${i} $@
            if [ $? -eq 0 ]; then
                i=$((i + 1))
                EMULATOR_CONF="${!i}"
            fi
        elif [ "${!i}" == "-r" ] || [ "${!i}" == "--root" ]; then
            ROOT_ENV=1
            argument_parameter_exists ${i} $@
            if [ $? -eq 0 ]; then
                i=$((i + 1))
                ROOT_CONF="${!i}"
            fi
        else
            std_err "Unknown argument: ${!i}\n"
            std_err "${USAGE}"
            std_err "See -h for more information"
            exit 1
        fi
    done

    if [ ${show_help} -eq 1 ]; then
        print_help
        exit
    fi

    if [ ${SETUP_TOOLS} -eq 0 ] && [ ${EMULATOR_ENV} -eq 0 ] && [ ${ROOT_ENV} -eq 0 ] && [ ${WIPE} -eq 0 ]; then
        std_err "${USAGE}"
        std_err "See -h for more information"
        exit 1
    fi

    if [ ${WIPE} -eq 1 ] && [ ! -f ${WIPE_CONF} ]; then
        std_err "Wipe tools configuration file does not exist!"
        exit 1
    fi

    if [ ${SETUP_TOOLS} -eq 1 ] && [ ! -f ${TOOLS_CONF} ]; then
        std_err "Setup tools configuration file does not exist!"
        exit 1
    fi

    if [ ${EMULATOR_ENV} -eq 1 ] && [ ! -f ${EMULATOR_CONF} ]; then
        std_err "Emulation detection evasion configuration file does not exist!"
        exit 1
    fi

    if [ ${ROOT_ENV} -eq 1 ] && [ ! -f ${ROOT_CONF} ]; then
        std_err "Root detection evasion configuration file does not exist!"
        exit 1
    fi
} # parse_arguments()

wipe_tools() {
    if [ ${WIPE} -eq 1 ]; then
        local modifiers=""
        if [ ${SILENT_MODE} -eq 1 ]; then
            modifiers="${modifiers} --silent"
        fi

        ${ROOT_DIR}/setup/wipe-tools.sh ${modifiers} ${WIPE_CONF}
    fi
} # wipe_tools()

check_root() {
    if [ $(id -u) -ne 0 ] && [ ${EMULATOR_ENV} -eq 1 ]; then
        prompt_root
        [ $? -eq 0 ] || exit 1
    fi
} # check_root()

setup_tools() {
    if [ ${SETUP_TOOLS} -eq 1 ]; then
        local modifiers=""
        if [ ${SILENT_MODE} -eq 1 ]; then
            modifiers="${modifiers} --silent"
        fi

        ${ROOT_DIR}/setup/setup-tools.sh ${modifiers} ${TOOLS_CONF}
    fi
} # setup_tools()

offline_emulation_modification() {
    local modifiers=""
    if [ ${SILENT_MODE} -eq 1 ]; then
        modifiers="--silent"
    fi

    if [ ${DO_BACKUP} -eq 1 ]; then
        modifiers="${modifiers} --backup"
    fi

    printf "${ROOT_PASSWORD}\n" | ${ROOT_DIR}/modify/emulation-detection-evasion.sh ${modifiers} ${EMULATOR_CONF}
} # offline_emulation_modification()

root_modification() {
    local modifiers=""
    if [ ${SILENT_MODE} -eq 1 ]; then
        modifiers="--silent"
    fi

    ${ROOT_DIR}/modify/root-detection-evasion.sh ${modifiers} ${ROOT_CONF}
} # root_modification()

offline_modification() {
    [ ${EMULATOR_ENV} -eq 1 ] && offline_emulation_modification
} # offline_modification()

online_modification() {
    [ ${ROOT_ENV} -eq 1 ] && root_modification
} # online_modification()

check_dependencies
parse_arguments $@

println "Started $(date)"
check_root
wipe_tools
setup_tools
offline_modification
online_modification
println "Finished $(date)"
