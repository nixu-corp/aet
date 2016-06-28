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
