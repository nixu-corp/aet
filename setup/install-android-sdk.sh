#!/bin/bash

EXEC_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"
EXEC_DIR="${EXEC_DIR%/}"
source ${EXEC_DIR}/setup-utilities.sh
LOG_DIR="${ROOT_DIR}/logs"
LOG_FILE="AET.log"

USAGE="Usage: ./install-android-sdk.sh <download directory> <android sdk directory> <android sdk tgz file> [-a android apis] [-g google apis] [-d|--debug] [-s|--silent]"
HELP_TEXT="
OPTIONS
-a <android apis>           API's comma-separated; eg 23 for Android SDK 23
-g <google apis>            API's comma-separated; eg 23 for Google SDK 23
-d, --debug                 Debug mode, command output is logged to logs/AET.log
-s, --silent                Silent mode, suppresses all output except result
-h, --help                  Display this help and exit

<download directory>
<android sdk directory>     Android SDK installation directory
<android sdk tgz file>      The android sdk download file name"

DEBUG_MODE=0
SILENT_MODE=0

DOWNLOAD_DIR=""
ASDK_DIR=""
SDK_FILE=""

A_APIS=()
G_APIS=()

parse_arguments() {
    local show_help=0
    for ((i = 1; i <= $#; i++)); do
        if [ "${!i}" == "-s" ] || [ "${!i}" == "--silent" ]; then
            SILENT_MODE=1
        elif [ "${!i}" == "-h" ] || [ "${!i}" == "--help" ]; then
            show_help=1
        elif [ "${!i}" == "-d" ] || [ "${!i}" == "--debug" ]; then
            DEBUG_MODE=1
        elif [ "${!i}" == "-a" ]; then
            while true; do
                argument_parameter_exists ${i} $@
                if [ $? -eq 0 ]; then
                    i=$((i + 1))
                    A_APIS+=("${!i}")
                else
                    break
                fi
            done
        elif [ "${!i}" == "-g" ]; then
            while true; do
                argument_parameter_exists ${i} $@
                if [ $? -eq 0 ]; then
                    i=$((i + 1))
                    G_APIS+=("${!i}")
                else
                    break
                fi
            done
        elif [ -z "${DOWNLOAD_DIR}" ]; then
            DOWNLOAD_DIR="${!i/\~/${HOME}}"
        elif [ -z "${ASDK_DIR}" ]; then
            ASDK_DIR="${!i/\~/${HOME}}"
        elif [ -z "${SDK_FILE}" ]; then
            SDK_FILE="${!i/\~/${HOME}}"
        else
            std_err "Unknown argument: ${!i}"
            std_err "${USAGE}"
            std_err "See -h for more info"
            exit 1
        fi
    done

    if [ ${show_help} -eq 1 ]; then
        print_help
        exit
    fi

    if [ -z "${DOWNLOAD_DIR}" ] \
    || [ -z "${ASDK_DIR}" ] \
    || [ -z "${SDK_FILE}" ]; then
        std_err "${USAGE}"
        std_err "See -h for more info"
        exit 1
    fi

    if [ ${#A_APIS[@]} -eq 0 ] && [ ${#G_APIS[@]} -eq 0 ]; then
        std_err "No API's have been specified!"
        exit 1
    fi

    DOWNLOAD_DIR=${DOWNLOAD_DIR%/}
    ASDK_DIR=${ASDK_DIR%/}

    log "INFO" "$(mkdir -p ${DOWNLOAD_DIR} 2>&1)"
    log "INFO" "$(mkdir -p ${ASDK_DIR} 2>&1)"
} # parse_arguments()

install_android_sdk() {
    printfln "---------------------------------------"
    println "Installing Android SDK"
    printfln "---------------------------------------"
    download_file "https://dl.google.com/android/android-sdk_r22.0.5-linux.tgz" "${DOWNLOAD_DIR}" "${SDK_FILE}"
    if [ $? -ne 0 ]; then exit 1; fi
    check_downloaded_file "${DOWNLOAD_DIR}/${SDK_FILE}"
    if [ $? -ne 0 ]; then exit 1; fi
    unzip_file "${DOWNLOAD_DIR}" "${SDK_FILE}" "${ASDK_DIR}"
    if [ $? -ne 0 ]; then exit 1; fi
    println "\n"
} # install_android_sdk()

install_sdk_packages() {
    printfln "---------------------------------------"
    println "Installing Android SDK packages"
    printfln "---------------------------------------"

    local -a retry_packages=()
    local -a packages_info=()
    local package_ID=""
    local package_name=""
    local package_desc=""
    local previous_ID=""
    local previous_name=""
    local previous_desc=""
    local previous_count=0
    local -i round_done=0

    local grepstr=""
    local grepstr_bak=""
    local -i retry_count=1
    local -i retry_counter=0

    local -a packages
    packages[0]="platform-tools"
    packages[1]="tools"
    packages[2]="build-tools-"
    
    for api in ${A_APIS[@]}; do
        packages+=("${api}")
    done

    for api in ${G_APIS[@]}; do
        packages+=("${api}")
    done

    grepstr="^\("
    for package in ${packages[@]}; do
        grepstr="${grepstr}${package}\|"
    done
    grepstr=${grepstr%\\|}
    grepstr="${grepstr}\)"
    grepstr_bak=${grepstr}

    get_packages_info

    while [ ${#packages_info[@]} -gt 0 ]; do
        round_done=1
        for p in "${packages_info[@]}"; do
            extract_package_info "${p}"
            process_package_info ${grepstr}
            if [ $? -eq 0 ]; then round_done=0; fi
        done

        if [ ${round_done} -eq 1 ]; then
            if [ ${#retry_packages[@]} -gt 0 ]; then
                if [ ${retry_counter} -lt ${retry_count} ]; then
                    println ""
                    println "Retrying to install skipped packages"
                    println "${retry_packages[@]}"
                    packages_info=${retry_packages}
                    retry_packages=()
                    grepstr=${grepstr_bak}
                    previous_ID=""
                    previous_name=""
                    previous_desc=""
                    previous_count=0
                    retry_counter=$((retry_counter + 1))
                else
                    printfln "---"
                    println "Failed to install some packages"
                    println ""
                    return
                fi
            else
                printfln "---"
                if [ ${previous_count} -eq 0 ]; then
                    println "No packages were installed"
                else
                    println "Successfully installed packages"
                fi
                println ""
                return
            fi
        else
            get_packages_info
        fi 
    done
    std_err "Failed to install packages!"
    println ""
} # install_sdk_packages()

get_packages_info() {
    local package_data=$(${ASDK_DIR}/$(ls ${ASDK_DIR})/tools/android list sdk --extended 2>/dev/null) &>/dev/null
    local package_info=""
    local split_regex="^---\+"
    local id_regex="\(id: .*\)"
    local desc_regex="[[:blank:]]*\(Desc: .*\)"

    packages_info=()

    while read line; do
        local id_capture=$(expr "${line} " : "${id_regex}")
        local desc_capture=$(expr "${line} " : "${desc_regex}")

        if [ ! -z "${id_capture}" ]; then
            package_info="${package_info} ${id_capture}"
            package_info="$(printf "${package_info}" | sed "s/[[:space:]]\+/ /g")"
        elif [ ! -z "${desc_capture}" ]; then
            package_info="${package_info} ${desc_capture}"
            package_info="$(printf "${package_info}" | sed "s/[[:space:]]\+/ /g")"
            package_info="$(printf "${package_info}" | sed "s/,//g")"
        elif [ $(expr "${line}" : "${split_regex}") -gt 0 ]; then
            if [ ! -z "${package_info}" ]; then
                packages_info+=("${package_info}")
            fi
            package_info=""
        fi
    done <<< "${package_data}"

    if [ ! -z "${package_info}" ]; then
        packages_info+=("${package_info}")
        package_info=""
    fi
} # get_package_info()

extract_package_info() {
    local package_info="${1}"
    local id_capture=$(expr "${package_info}" : "[[:blank:]]*id: \([0-9]\+\)")
    local name_capture=$(expr "${package_info}" : ".*\?or \"\(.*\)\"")
    local desc_capture=$(expr "${package_info}" : ".*\?Desc: \(.*\)")
    package_ID=""
    package_name=""
    package_desc=""

    if [ ! -z "${id_capture}" ]; then
        package_ID="${id_capture}"
    fi

    if [ ! -z "${name_capture}" ]; then
        package_name="${name_capture}"
    fi

    if [ ! -z "${desc_capture}" ]; then
        package_desc="${desc_capture}"
        package_desc=$(printf "${package_desc}" | sed "s/[[:blank:]]*$//")
    fi
} # extract_package_info()

process_package_info() {
    local wanted_regex="${1}"

    if [ -z "$(expr "${package_name}" : "${wanted_regex}")" ]; then
        return 1
    fi

    if [ "${previous_ID}" == "${package_ID}" ] \
    && [ "${previous_name}" == "${package_name}" ] \
    && [ "${previous_desc}" == "${package_desc}" ]; then
        previous_count=$((previous_count + 1))
    else
        previous_count=1
    fi

    if  [ ${previous_count} -gt 2 ]; then
        println "Skipping ${package_desc}..."
        retry_packages+=("id: ${package_ID} or \"${package_name}\" Desc: ${package_desc}")
        grepstr=$(printf "${grepstr}" | sed "s/${package_name}|\?//")
        grepstr="${grepstr%|)}"
        grepstr="${grepstr%)})"
    else
        install_package
    fi
} # process_package_info()

install_package() {
    loading "Installing ${package_desc}" &
    local output="$(printf "y" | ${ASDK_DIR}/$(ls ${ASDK_DIR})/tools/android update sdk --no-ui --filter ${package_name} 2>&1)"
    log "INFO" "${output}"
    previous_ID=${package_ID}
    previous_name=${package_name}
    previous_desc=${package_desc}
    kill $!
    trap 'kill $1' SIGTERM
    clear_println "Installed ${package_desc}"
} # install_package()

parse_arguments $@
install_android_sdk
install_sdk_packages
