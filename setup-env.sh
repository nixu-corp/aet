#!/bin/bash

set -u

# setup-env.sh variables
USAGE="Usage: ./setup-env.sh [-s|--silent] [-e configuration file] [-m configuration file]"
HELP_TEXT="
OPTIONS
-e                      Installs the environment and the necessary tools
-m                      Modifies the environment to evade emulation detection
-s, --silent            Silent mode, supresses all output except result
-h                      Display this help and exit

<configuration file>    The configuration file belonging to each script"
HELP_MSG="${USAGE}\n${HELP_TEXT}"

SETUP_TOOLS=0
MODIFY_ENV=0

# setup-tools.sh variables
TOOLS_CONF=""
MODIFY_CONF=""

parse_arguments() {
    if [ $# -eq 0 ]; then
        printf "${USAGE}\n"
        printf "See -h for more info\n"
        exit
    fi

    while getopts ":hm:s:" opt ; do
        case $opt in
            h)
                printf "${HELP_MSG}\n"
                exit
            ;;
            m)
                MODIFY_ENV=1
                MODIFY_CONF=${OPTARG}
            ;;
            s)
                SETUP_TOOLS=1
                TOOLS_CONF=${OPTARG}
            ;;
            *)
                printf "Invalid flag '-${OPTARG}'!\n"
                printf "${USAGE}\n"
                printf "See -h for more info\n"
                exit
            ;;
        esac
    done
} # parse_arguments()

setup_tools() {
    if [ ${SETUP_TOOLS} -eq 1 ]; then
        ./setup-tools.sh ${TOOLS_CONF}
    fi
} # setup_tools()

modify_env() {
    if [ ${MODIFY_ENV} -eq 1 ]; then
        ./modify-env.sh ${MODIFY_CONF}
    fi
} # modify_env()


parse_arguments $@
setup_tools
modify_env
