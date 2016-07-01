#!/bin/bash

set -u

EXEC_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"
EXEC_DIR="${EXEC_DIR%/}"
ROOT_DIR="$(cd "${EXEC_DIR}/.." && pwd)"
ROOT_DIR="${ROOT_DIR%/}"
source ${ROOT_DIR}/utilities.sh

USAGE="Usage: ./setup-env.sh [-b|--backup] [-s|--silent] [-e configuration file] [-m configuration file]"
HELP_TEXT="
OPTIONS
-b, --backup            Enable backup for modification scripts
-e, --environment       Installs the environment and the necessary tools
-m, --modify            Modifies the environment to evade emulation detection
-s, --silent            Silent mode, suppresses all output except result
-h, --help              Display this help and exit

<configuration file>    The configuration file belonging to each script"
HELP_MSG="${USAGE}\n${HELP_TEXT}"

ROOT=0
SETUP_TOOLS=0
MODIFY_ENV=0
DO_BACKUP=0

ROOT_PASSWORD=""
TOOLS_CONF=""
MODIFY_CONF=""

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
        elif [ "${!i}" == "-e" ] || [ "${!i}" == "--environment" ]; then
            SETUP_TOOLS=1
            i=$((i + 1))
            check_option_value ${i} $@
            if [ $? -eq 1 ]; then
                std_err "No configuration file given for '-e'!\n"
                std_err "${USAGE}"
                std_err "See -h for more information"
                exit 1
            else
                TOOLS_CONF="${!i}"
            fi
        elif [ "${!i}" == "-m" ] || [ "${!i}" == "--modify" ]; then
            MODIFY_ENV=1
            i=$((i + 1))
            check_option_value ${i} $@
            if [ $? -eq 1 ]; then
                std_err "No configuration file given for '-m'!\n"
                std_err "${USAGE}"
                std_err "See -h for more information"
                exit 1
            else
                MODIFY_CONF="${!i}"
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

    if [ ${SETUP_TOOLS} -eq 0 ] && [ ${MODIFY_ENV} -eq 0 ]; then
        std_err "${USAGE}"
        std_err "See -h for more information"
        exit 1
    fi

    if [ ${SETUP_TOOLS} -eq 1 ] && [ ! -f ${TOOLS_CONF} ]; then
        std_err "Setup tools configuration file does not exist!"
        exit 1
    fi

    if [ ${MODIFY_ENV} -eq 1 ] && [ ! -f ${MODIFY_CONF} ]; then
        std_err "Modify environment configuration file does not exist!"
        exit 1
    fi
} # parse_arguments()

check_root() {
    if [ $(id -u) -ne 0 ] && [ ${MODIFY_ENV} -eq 1 ]; then
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

modify_env() {
    if [ ${MODIFY_ENV} -eq 1 ]; then
        local modifiers=""
        if [ ${SILENT_MODE} -eq 1 ]; then
            modifiers="--silent"
        fi

        if [ ${DO_BACKUP} -eq 1 ]; then
            modifiers="${modifiers} --backup"
        fi

        printf "${ROOT_PASSWORD}\n" | ${ROOT_DIR}/modify/modify-env.sh ${modifiers} ${MODIFY_CONF}
    fi
} # modify_env()

check_dependencies
parse_arguments $@

println "Started $(date)"
check_root
setup_tools
modify_env
println "Finished $(date)"
