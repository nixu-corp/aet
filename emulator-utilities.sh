#!/bin/bash

source utilities.sh

check_avd() {
    local avd_name_grep=$(${ASDK_DIR}/$(ls ${ASDK_DIR})/tools/android list avd | grep "Name: ${1}$")

    if [ -z "${avd_name_grep}" ]; then
        std_err "There is no AVD with that name!"
        exit 1
    fi
} # check_avd()

start_avd() {
    println "Starting AVD: ${1}"
    local opts=""
    [ $# -ge 2 ] && opts="${2}"
    ${ASDK_DIR}/$(ls ${ASDK_DIR})/tools/emulator -avd "${1}" "${opts}" -partition-size 2047 &>/dev/null &
} # start_avd()

reboot_avd() {
    println "Rebooting Android Virtual Device"
    ${ASDK_DIR}/$(ls ${ASDK_DIR})/platform-tools/adb shell su -c setprop ctl.restart zygote
} # reboot_avd()

wait_for_device() {
    write "Waiting"
    local output=""
    local timeout_sec=60
    local ret=1
    printf "1" > /dev/shm/emulator-tmp.txt

    while true; do
        # getprop appends a \r at the end of the string and that is why 'tr' is used here
        output="$(${ASDK_DIR}/$(ls ${ASDK_DIR})/platform-tools/adb wait-for-device shell getprop init.svc.bootanim | tr -cd '[[:alpha:]]')"
        sleep 2
        if [ "${output}" == "stopped" ]; then
            printf "0" > /dev/shm/emulator-tmp.txt
            break
        fi
    done &

    while true; do
        write "."
        sleep 1
        timeout_sec=$((timeout_sec - 1))
        ret=$(</dev/shm/emulator-tmp.txt)
        if [ ${timeout_sec} -le 0 ]; then
            kill $!
            trap 'kill $1' SIGTERM
            break
        fi

        [ ${ret} -eq 0 ] && break
    done

    rm /dev/shm/emulator-tmp.txt &>/dev/null

    println ""
    return ${ret}
} # wait_for_device()
