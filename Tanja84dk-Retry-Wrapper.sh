#!/usr/bin/env bash
set -o pipefail

function fatal() {
    local msg="$1"
    printf "[ERROR] %s\n" "${msg}"
    exit 1
}

IGNORE_RETURN_CODE="False"

[[ $1 =~ ^[0-9]+$ ]] || fatal "Argument 1 has to be the number of retry attempts"

retry_attempts=$1
upper_limit_retry=$((retry_attempts * 10))
shift

[[ $1 =~ ^[0-9]+$ ]] || fatal "Argument 2 has to be the time waiting between retries in seconds"
wait_seconds=$1
shift

if [[ "$1" == "--ignore-code" ]]; then
    IGNORE_RETURN_CODE="True"
    shift
fi

[[ ! -z ${1+x} ]] || fatal "Missing the command to run within the retry wrapper"

arg_command_array=("$@")

function run_command() {
    local return_code=""

    "${arg_command_array[@]}"
    return_code=$?
    return $return_code
}

function retry_command_loop() {
    local retry_counter=1
    local retry_loops=0
    local timestamp1
    local timestamp2
    local timestamp_difference
    timestamp1=$(date +%s)
    timestamp2=$(date +%s)
    local sleep_timer=$((wait_seconds))
    local return_code=""

    while ((retry_counter <= retry_attempts)); do
        if ((retry_loops >= upper_limit_retry)); then fatal "To many retries"; fi
        timestamp1=$(date +%s)
        sleep_timer=$((sleep_timer))
        run_command
        return_code=$?

        if ((return_code == 0)) && [[ $IGNORE_RETURN_CODE == "False" ]]; then return "$return_code"; fi
        timestamp2=$(date +%s)

        if ((retry_counter > 0)); then
            printf "Retrying in %s seconds\n" "$sleep_timer"
        fi

        if ((retry_counter < retry_attempts)); then
            sleep "$wait_seconds"
        fi

        timestamp_difference=$((timestamp2 - timestamp1))

        if [ $timestamp_difference -lt "10" ]; then
            retry_counter=$((retry_counter + 1))
            printf "Retry Attempt: %s\n" "$retry_counter"
        else
            printf "Retried Attempt: %s\n" "$retry_counter"
            printf "Resetting Attempts\n"
            retry_loops=$((retry_loops + 1))
            retry_counter=1
            sleep_timer=$((wait_seconds))
        fi
    done
    return $return_code
}

function entry_wrapper() {
    if [ "$retry_attempts" -lt 2 ]; then
        run_command
    else
        retry_command_loop
    fi
}

entry_wrapper
