#!/bin/bash

# This script will allow a command to be run at a later time, much like "at".
# However, it uses a bash shell by default.

# It takes the following arguments:
#   $1 = time to run script or command, quoted if it has spaces
#       Accepted format of run time is the same as for the date --date command.
#   $2 = command or script to be run, quoted if it has spaces


### Set help variables ####################################################

usage='usage: run-at.sh [-b] [-h] [-k pid] [-l] [time] [command]'
help_text="$usage

This script schedules a command or script to run at a later time. It is
similar in some ways to the \"at\" command, but there are also some important
differences.

By default, this script will run in the foreground and show a countdown timer,
but it can be run as a background process by passing the \"-b\" option.

    -b          run countdown and scheduled script in background, then exit
                The following info will be returned:
                <pid> <run-at path> <scheduled time> <command to be run>

    -h          display this help and exit

    -k <pid>    kill scheduled command with given pid and exit

    -l          list all currently scheduled commands and exit
                Commands will be shown with the following structure:
                <pid> <run-at path> <scheduled time> <command to be run>

If <scheduled time> and <command to be run> are not given, the user will be
prompted for them. If <scheduled time> has any spaces, it must be quoted.
"


### Functions #############################################################

# Get run time from user
get_run_time_input ()
    {
    echo "Enter desired run time:"
    read -p "> " run_time
    prepare_input "$run_time"
    run_time="$prepared"
    }

# Get command from user
get_command_input ()
    {
    echo "Enter command or script to run:"
    read -p "> " to_run
    
    read -p "Run output background [0] or foreground [1]? " answer
    show=$answer
    echo
    }

# Enure that quotes in input are preserved
prepare_input ()
    {
    input="$@"
    prepared=
    for i in "$@"; do
        add="\"$i\""
        prepared+="$add "
    done
    }

# Find all running instances of run-at.sh & their pids
get_run_at_processes ()
    {
    run_at_processes=$(top -bc -n1 -w200 | grep 'run-at' | grep -v 'grep' \
        | head -n-2 | sed -r 's@^\s(.*)$@\1@' | cut -d' ' -f1,31-)
    run_at_pids=$(echo "$run_at_processes" | sed -r 's@^([0-9]*)\s.*$@\1@')
    }

# Get the current time
get_now ()
    {
    now_secs=$(date +%s)
    now_readable=$(date -d @${run_secs} +%T)
    }

# Calculate time remaining
get_countdown_to ()
    {
    get_now
    remaining=$(($1-$now_secs))
    countdown=$(date -u -d @${remaining} +%T)
    }

# Display time remaining until it equals zero
wait_until ()
    {
    while [[ $now_secs < $1 ]]; do
        echo -en "\r$countdown until execution..."
        sleep 0.99s
        get_countdown_to $1
    done
    echo -en "\r\033[K"
    }

# Run the countdown sequence, then the given command
run_countdown_and_command ()
    {
    echo \'"$to_run"\'" will run at $run_readable"

    get_countdown_to $run_secs
    wait_until $run_secs

    get_now
    echo "Started at $now_readable"
    echo

    # Run the command
    eval "$to_run"
    }


### Main execution ########################################################

# Set default option for visibility
show=1

# Check for option passed
while getopts ":bhk:l" opt; do
    case $opt in
        b) # runs script in background
            show=0
            ;;
        h) # print help text & exit
            echo "$help_text"
            exit 0
            ;;
        k) # kill given run-at pid & exit
            pid=$OPTARG
            get_run_at_processes
            if [[ $(echo "$run_at_pids" | grep "$pid") ]]
                then
                    kill -n 15 $pid
                else
                    echo "Error: \"$pid\" is not a valid run-at.sh pid"
            fi
            exit 0
            ;;
        l) # list pids of all current run-at scripts & exit
            get_run_at_processes
            if [[ $run_at_processes != '' ]]; then
                echo "$run_at_processes"
            fi
            exit 0
            ;;
        \?) # message for invalid option(s)
            echo "$usage"
            exit 1
    esac
done
shift $(($OPTIND - 1))

# Set command or script to run and the run time
if [[ $# < 1 ]]; then
    # no time or command were given as args
    get_run_time_input
    get_command_input
elif [[ $# < 2 ]]; then
    # assume time is given, but not command
    prepare_input "$1"
    run_time="$prepared"
    get_command_input
else
    # assume time is given first & quoted if containing spaces
    #   assume any remaining args belong to the command to be run
    prepare_input "$1"
    run_time="$prepared"
    shift
    prepare_input "$@"
    to_run="$prepared"
fi

# Set input time in epoch secs & human-readable formats
run_secs=$(eval date -d "$run_time" +%s)
run_readable=$(date -d @${run_secs} +%T)

# If selected, restart script and run in background
if [[ $show == 0 ]]; then
    eval "$0 $run_time $to_run >/dev/null &"
    bg_pid=$!
    echo "$bg_pid $0 $run_time $to_run"
else
    run_countdown_and_command
fi


exit 0