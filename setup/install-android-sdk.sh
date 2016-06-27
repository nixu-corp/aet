#!/bin/bash

EXEC_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"
source ${EXEC_DIR}/setup-utilities.sh

DOWNLOAD_DIR=""
ASDK_DIR=""
SDK_FILE=""

A_APIS=()
G_APIS=()

parse_arguments() {
    DOWNLOAD_DIR="$1"
    ASDK_DIR="$2"
    SDK_FILE="$3"

    DOWNLOAD_DIR=${DOWNLOAD_DIR%/}
    ASDK_DIR=${ASDK_DIR%/}

    mkdir -p ${DOWNLOAD_DIR} &>/dev/null
    mkdir -p ${ASDK_DIR} &>/dev/null

    for ((i = 4; i <= $#; i++)); do
        if [ "${!i}" == "-a" ]; then
            i=$((i + 1))
            for ((j=${i}; j <= $#; j++)); do
                if [ "${!j}" == "-g" ]; then
                    i=$((j - 1))
                    break
                fi
                A_APIS+=("${!j}")
            done  
        elif [ "${!i}" == "-g" ]; then
            i=$((i + 1))
            for ((j = ${i}; j <= $#; j++)); do
                if [ "${!j}" == "-a" ]; then
                    i=$((j - 1))
                    break
                fi
                G_APIS+=("${!j}")
            done
        fi
    done
} # parse_arguments()

install_android_sdk() {
    printf "%s\n" "---------------------------------------"
    printf "%s\n" "Installing Android SDK"
    printf "%s\n" "---------------------------------------"
    download_file "https://dl.google.com/android/android-sdk_r22.0.5-linux.tgz" "${DOWNLOAD_DIR}" "${SDK_FILE}"
    if [ $? -ne 0 ]; then exit 1; fi
    check_downloaded_file "${DOWNLOAD_DIR}/${SDK_FILE}"
    if [ $? -ne 0 ]; then exit 1; fi
    unzip_file "${DOWNLOAD_DIR}" "${SDK_FILE}" "${ASDK_DIR}"
    if [ $? -ne 0 ]; then exit 1; fi
    printf "%s\n" ""
} # install_android_sdk()

install_sdk_packages() {
    printf "%s\n" "---------------------------------------"
    printf "%s\n" "Installing Android SDK packages"
    printf "%s\n" "---------------------------------------"

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
                    printf "%s\n" ""
                    printf "%s\n" "Retrying to install skipped packages"
                    printf "%s\n" "${retry_packages[@]}"
                    packages_info=${retry_packages}
                    retry_packages=()
                    grepstr=${grepstr_bak}
                    previous_ID=""
                    previous_name=""
                    previous_desc=""
                    previous_count=0
                    retry_counter=$((retry_counter + 1))
                else
                    printf "%s\n" "---"
                    printf "%s\n" "Failed to install some packages"
                    break
                fi
            else
                printf "%s\n" "---"
                if [ ${previous_count} -eq 0 ]; then
                    printf "%s\n" "No packages were installed"
                else
                    printf "%s\n" "Successfully installed packages"
                fi
                break
            fi
        else
            get_packages_info
        fi 
        
    done
    printf "%s\n" ""
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
        printf "%s\n" "Skipping ${package_desc}..."
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
    (printf "y" | ${ASDK_DIR}/$(ls ${ASDK_DIR})/tools/android update sdk --no-ui --filter ${package_name}) &>/dev/null
    previous_ID=${package_ID}
    previous_name=${package_name}
    previous_desc=${package_desc}
    kill $!
    trap 'kill $1' SIGTERM
    printf "\r$(tput el)"
    printf "%s\n" "Installed ${package_desc}"
} # install_package()

parse_arguments $@
install_android_sdk
install_sdk_packages
