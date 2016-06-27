#!/bin/bash

ROOT_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})/.." && pwd)"
ROOT_DIR="${ROOT_DIR%/}"
SILENT_MODE=0

SPIN[0]="-"
SPIN[1]="\\"
SPIN[2]="|"
SPIN[3]="/"

loading() {
    local message=${1}
    while true; do
        for s in "${SPIN[@]}"; do
            clear_print "[${message}] ${s}"
            sleep 0.1
        done
    done
} # loading()

write() {
    if [ "${SILENT_MODE}" == "0" ]; then
        if [ $# -ge 2 ]; then
            printf "${1}" "${2}"
        elif [ $# -eq 1 ]; then
            printf "${1}"
        fi
    fi
} # message()

println() {
    write "${1}\n"
} # println()

printfln() {
    write "%s\n" "${1}"
} # printfln()

clear_print() {
    write "\r$(tput el)"
    write "${1}"
} # clear_print()

clear_println() {
    clear_print "${1}"
    write "\n"
} # clear_println()

clear_printf() {
    write "\r$(tput el)"
    write "%s" "${1}"
} # clear_printf()

clear_printfln() {
    clear_printf "${1}"
    write "\n"
} # clear_printfln()

download_file() {
    local url="${1}"
    local dir="${2}"
    local file="${3}"
    local progress_modifier="--show-progress"
    if [ "${SILENT_MODE}" == "1" ]; then
        progress_modifier=""
    fi
    println "Downloading: ${dir}/\033[1;35m${file}\033[0m"
    wget -q ${progress_modifier} -O "${dir}/${file}" "${url}"
} # download_android_sdk()

check_downloaded_file() {
    local full_file="${1}"
    local file="$(basename ${full_file})"
    
    println "Checking integrity of: \033[1;35m${file}\033[0m"

    local reference_data=$(grep "${file}" "${ROOT_DIR}/security/file-download-reference.txt")

    if [ -z "${reference_data}" ]; then
        println "Unknown file!"
        return 1
    fi

    local reference_sha1=$(printf "%s" "${reference_data}" | cut -d '|' -f 3)
    local sha1=$(sha1sum "${full_file}" | sed "s/[[:blank:]].*//")
    
    if [ "${sha1}" != "${reference_sha1}" ]; then
        println "[\033[0;31mFAIL\033[0m] SHA1 checksum mismatch!"
        println "Downloaded file's SHA1: ${sha1}"
        println "Correct SHA1            ${reference_sha1}"
        return 1
    else
        println "[\033[0;32mOK\033[0m]   SHA1 checksum match"
    fi

    local reference_size=$(printf "%s" "${reference_data}" | cut -d '|' -f 2)
    local size=$(du -b ${full_file} | sed "s/[[:blank:]].*//")

    if [ "${size}" != "${reference_size}" ]; then
        println "[\033[0;31mFAIL\033[0m] File size mismatch!"
        println "Downloaded file's size: ${size}"
        println "Correct file size:      ${reference_size}"
        return 1
    else
        println "[\033[0;32mOK\033[0m]   File size match"
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
    rm "${src_dir}/${file}" &>/dev/null
    clear_println "[Unzipping \033[1;35m${file}\033[0m] Done."
} # unzip_android_sdk
