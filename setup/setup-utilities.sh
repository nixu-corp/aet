#!/bin/bash

ROOT_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})/.." && pwd)"

SPIN[0]="-"
SPIN[1]="\\"
SPIN[2]="|"
SPIN[3]="/"

loading() {
    local message=${1}
    while true; do
        for s in "${SPIN[@]}"; do
            printf "\r$(tput el)"
            printf "[${message}] ${s}"
            sleep 0.1
        done
    done
} # loading()

download_file() {
    local url="${1}"
    local dir="${2}"
    local file="${3}"
    printf "Downloading: ${dir}/\033[1;35m${file}\033[0m\n"
    wget -q --show-progress -O "${dir}/${file}" "${url}"
} # download_android_sdk()

check_downloaded_file() {
    local full_file="${1}"
    local file="$(basename ${full_file})"
    
    printf "Checking integrity of: \033[1;35m${file}\033[0m\n"

    local reference_data=$(grep "${file}" "${ROOT_DIR}/security/file-download-reference.txt")

    if [ -z "${reference_data}" ]; then
        printf "\r$(tput el)"
        printf "Unknown file!\n"
        return 1
    fi

    local reference_sha1=$(printf "%s" "${reference_data}" | cut -d '|' -f 3)
    local sha1=$(sha1sum "${full_file}" | sed "s/[[:blank:]].*//")
    
    if [ "${sha1}" != "${reference_sha1}" ]; then
        printf "[\033[0;31mFAIL\033[0m] SHA1 checksum mismatch!\n"
        printf "Downloaded file's SHA1: ${sha1}\n"
        printf "Correct SHA1            ${reference_sha1}\n"
        return 1
    else
        printf "[\033[0;32mOK\033[0m]   SHA1 checksum match\n"
    fi

    local reference_size=$(printf "%s" "${reference_data}" | cut -d '|' -f 2)
    local size=$(du -b ${full_file} | sed "s/[[:blank:]].*//")

    if [ "${size}" != "${reference_size}" ]; then
        printf "[\033[0;31mFAIL\033[0m] File size mismatch!\n"
        printf "Downloaded file's size: ${size}\n"
        printf "Correct file size:      ${reference_size}\n"
        return 1
    else
        printf "[\033[0;32mOK\033[0m]   File size match\n"
    fi
} # check_downloaded_file()

unzip_file() {
    local src_dir="${1}"
    local file="${2}"
    local dest_dir="${3}"
    mkdir -p ${dest_dir}
    loading "Unzipping \033[1;35m${file}\033[0m" &
    local extension="${file##*.}"
    if [ "${extension}" == "gz" ] || [ "${extension}" == "tgz" ]; then
        tar -zxvf "${src_dir}/${file}" -C "${dest_dir}" &>/dev/null
    elif [ "${extension}" == "zip" ]; then
        unzip -d "${dest_dir}" "${src_dir}/${file}" &>/dev/null
    else
        printf "Unknown file format"
    fi
    kill $!
    trap 'kill $1' SIGTERM
    printf "\r$(tput el)"
    printf "[Unzipping \033[1;35m${file}\033[0m] Done.\n"
} # unzip_android_sdk

