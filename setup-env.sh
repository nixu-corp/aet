#!/bin/bash

set -u

# setup-env.sh variables
read -d '' USAGE << "EOF"
Usage: ./setup-env.sh [OPTIONS...]
See -h for more info
EOF
SETUP_TOOLS=0
MODIFY_ENV=0

# setup-tools.sh variables
TOOLS_CONF=""
MODIFY_CONF=""

parse_arguments() {
    while getopts ":hm:s:" opt ; do
        case $opt in
            h)
                echo "${USAGE}"
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
                echo "Invalid flag '-${OPTARG}'!"
                echo "${USAGE}"
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
