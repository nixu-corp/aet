#!/bin/bash

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

print_help() {
    println "${USAGE}"
    println "${HELP_TEXT}"
} # show_help()

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

std_err() {
    println "${1}" 1>&2
} # std_err()

argument_parameter_exists() {
    local index="${1}"
    index=$((index + 2))

    if [ ${index} -gt $(($#)) ] \
    || [ $(expr "${!index}" : "^-.*$") -gt 0 ] \
    || [ $(expr "${!index}" : "^$") -gt 0 ]; then
        return 1
    else
        return 0
    fi
} # check_option_value()

prompt_root() {
    # @description This function prompts the user for their root password and stores
    # the result in 'ROOT_PASSWORD', if function fails then 'ROOT_PASSWORD' is
    # cleared
    #
    # @return If the user fails to give the correct password 3 times the function
    # returns 1, if succeeds then 0

    local failed_count=0
    while true; do
        read -s -p "[sudo] password for $(whoami): " ROOT_PASSWORD
        println ""
        println "${ROOT_PASSWORD}" | sudo -k -S -s ls &>/dev/null
        if [ $? -eq 0 ]; then
            return 0
        else
            failed_count=$((failed_count + 1))
            if [ ${failed_count} -ge 3 ]; then
                println "sudo: 3 incorrect password attempts"
                return 1
            fi
            println "Sorry, try again."
        fi
    done
} # prompt_root()
