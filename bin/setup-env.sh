#!/bin/bash

set -u

# setup-env.sh variables
USAGE="Usage: ./setup-env.sh [-s|--silent] [-r|--root] [-e configuration file] [-m configuration file]"
HELP_TEXT="
OPTIONS
-e, --environment       Installs the environment and the necessary tools
-m, --modify            Modifies the environment to evade emulation detection
-r, --root              Runs the necessary script(s) with root privileges
-s, --silent            Silent mode, suppresses all output except result
-h, --help              Display this help and exit

<configuration file>    The configuration file belonging to each script"
HELP_MSG="${USAGE}\n${HELP_TEXT}"

EXEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${EXEC_DIR}/.." && pwd)"

ROOT=0
SILENT_MODE=0
SETUP_TOOLS=0
MODIFY_ENV=0

ROOT_PASSWORD=""
TOOLS_CONF=""
MODIFY_CONF=""

print_usage() {
    printf "${USAGE}\n"
    printf "See -h for more info\n"
    exit
} # usage()

check_option_value() {
    local index="${1}"
    index=$((index + 1))

    if [ ${index} -gt $(($#)) ] \
    || [ $(expr "${!index}" : "^-.*$") -gt 0 ] \
    || [ $(expr "${!index}" : "^$") -gt 0 ]; then
        return 1
    else
        return 0
    fi
} # check_option_value()

parse_arguments() {
    if [ $# -eq 0 ]; then
        print_usage
    fi

    for ((i=1; i <= $#; i++)); do
        if [ "${!i}" == "-s" ] || [ "${!i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ "${!i}" == "-h" ] || [ "${!i}" == "--help" ]; then
            printf "${HELP_MSG}\n"
            exit
        elif [ "${!i}" == "-r" ] || [ "${!i}" == "--root" ]; then
            ROOT=1
        elif [ "${!i}" == "-e" ] || [ "${!i}" == "--environment" ]; then
            SETUP_TOOLS=1
            i=$((i + 1))
            check_option_value ${i} $@
            if [ $? -eq 1 ]; then
                printf "No configuration file given for '-e'!\n\n"
                print_usage
            else
                TOOLS_CONF="${!i}"
            fi
        elif [ "${!i}" == "-m" ] || [ "${!i}" == "--modify" ]; then
            MODIFY_ENV=1
            i=$((i + 1))
            check_option_value ${i} $@
            if [ $? -eq 1 ]; then
                printf "No configuration file given for '-m'!\n\n"
                print_usage
            else
                MODIFY_CONF="${!i}"
            fi
        else
            printf "Unknown argument: ${!i}"
            print_usage
        fi
    done

    if [ ${SETUP_TOOLS} -eq 1 ] && [ ! -f ${TOOLS_CONF} ]; then
        printf "Setup tools configuration file does not exist!\n"
        exit 1
    fi
    if [ ${MODIFY_ENV} -eq 1 ] && [ ! -f ${MODIFY_CONF} ]; then
        printf "Modify environment configuration file does not exist!\n"
        exit 1
    fi
} # parse_arguments()

check_root() {
    if [ ${ROOT} -eq 1 ] && [ ${MODIFY_ENV} -eq 1 ]; then
        local failed_count=0
        while true; do
            read -s -p "[sudo] password for $(whoami): " ROOT_PASSWORD
            printf "\n"
            printf "${ROOT_PASSWORD}\n" | sudo -k -S -s ls &>/dev/null
            if [ $? -eq 0 ]; then
                break
            else
                failed_count=$((failed_count + 1))
                if [ ${failed_count} -ge 3 ]; then
                    printf "sudo: 3 incorrect password attempts\n"
                    exit
                fi
                printf "Sorry, try again.\n"
            fi
        done
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
            modifiers="${modifiers} --silent"
        fi
        if [ ${ROOT} -eq 1 ]; then
            modifiers="${modifiers} --root ${ROOT_PASSWORD}"
        fi

        ${ROOT_DIR}/modify/modify-env.sh ${modifiers} ${MODIFY_CONF}
    fi
} # modify_env()


parse_arguments $@
check_root
setup_tools
modify_env
