#!/bin/bash

# This script will allow a command to be run at a later time, much like "at".
# However, it uses a bash shell by default.

# It takes the following arguments:
#   $1 = time to run script or command, quoted if it has spaces
#       Accepted format of run time is the same as for the date --date command.
#   $2 = command or script to be run, quoted if it has spaces


### Set main variables ####################################################

usage='usage: run-at.sh [-b] [-h] [-k pid] [-l] [time] [command]'
help_text="$usage

This script schedules a command or script to run at a later time. It is
similar in some ways to the \"at\" command, but there are also some important
differences. It uses a bash shell, for example.

By default, this script will run in the foreground and show a countdown timer,
but it can be run as a background process by passing the \"-b\" option.

    -b          Run countdown and scheduled script in background, then exit.
                The following info will be returned:
                <pid> <run-at path> <scheduled time> <command to be run>

    -h          Display this help and exit.

    -k <pid>    Kill scheduled command with given pid and exit.

    -l          List all currently scheduled commands and exit.
                Commands will be shown with the following structure:
                <pid> <run-at path> <scheduled time> <command to be run>

If <scheduled time> and <command to be run> are not given, the user will be
prompted for them.

Any values valid for $ date --date can be used for <scheduled time>. If
<scheduled time> has any spaces, it must be quoted.

If <command to be run> includes pipes, it needs to be double quoted. It's
probably best to double-quote it anyway.
"

### Default variables ####################################################

# Capture path to script for rerunning in background if requested.
script_path=$(realpath $0)

# Set default option for visibility of output.
show=1

### Functions #############################################################

# Get run time from user.
get_run_time_input ()
    {
    echo "Enter desired run time:"
    read -p "> " run_time
    }

# Get command from user.
get_command_input ()
    {
    echo "Enter command or script to run:"
    read -p "> " to_run
    
    read -p "Run output background [0] or foreground [1]? " answer
    show=$answer
    echo
    }

# Find all running instances of run-at.sh & their pids.
get_run_at_processes ()
    {
    run_at_processes=$(top -bc -n1 -w200 | grep 'run-at' | grep -v 'grep' \
        | head -n-2 | sed -r 's@^\s(.*)$@\1@' | cut -d' ' -f1,31-)
    run_at_pids=$(echo "$run_at_processes" | sed -r 's@^([0-9]*)\s.*$@\1@')
    }

# Get the current time.
get_now ()
    {
    now_secs=$(date +%s)
    now_readable=$(date -d @${run_secs} +%T)
    }

# Calculate time remaining.
get_countdown_to ()
    {
    get_now
    remaining=$(($1 - $now_secs))
    countdown=$(date -u -d @${remaining} +%T)
    }

# Display time remaining until it equals zero.
wait_until ()
    {
    while [[ $now_secs < $2 ]]; do
        if [[ $1 == 1 ]]; then
            echo -en "\r$countdown until execution..."
        fi
        sleep 0.99s
        get_countdown_to $2
    done
    if [[ $1 == 1 ]]; then
        echo -en "\r\033[K"
    fi
    }


### Main execution ########################################################

# Check for option passed.
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

# Set command or script to run and the run time.
if [[ $# < 1 ]]; then
    # No time or command were given as args.
    get_run_time_input
    get_command_input
elif [[ $# < 2 ]]; then
    # Assume time is given, but not command.
    run_time="$1"
    get_command_input
else
    # Assume time is given first & quoted if containing spaces.
    # Assume any remaining args belong to the command to be run.
    run_time="$1"
    shift
    to_run="$@"
fi

# Set input time in epoch secs & human-readable formats.
run_secs=$(date --date "$run_time" +%s)

# Adjust time to next day if necessary.
get_now
if [[ $now_secs > $run_secs ]]; then
    # Assume run time refers to the next day.
    run_secs=$((run_secs + 86400))
fi

run_readable=$(date --date @${run_secs} +%T)
run_filesafe=$(echo "$run_readable" | tr ':' '-')

# Set output file for background output.
output_log="$HOME/run-at-$run_filesafe.log"

# Find out if current script is in foreground or background.
case $(ps -o stat= -p $$) in
    *+*) # currently running in foreground
        bg=0
        ;;
    *) # currently running in background
        bg=1
        show=0
        ;;
esac

# Rerun script in background if requested.
if [[ $bg == 0 ]]; then
    if [[ $show == 0 ]]; then
        # -b option was passed, rerun script in background & exit this script.
        bash "$script_path" "$run_time" "$to_run" > "$output_log" 2>&1 &
        bg_pid=$!
        echo "$bg_pid $0 $run_time $to_run"
        exit 0
    fi
fi

# Announce run time if running in foreground.
if [[ $show == 1 ]]; then
    echo \'"$to_run"\'" will run at $run_readable"
fi

# Commence countdown to run time.
get_countdown_to $run_secs
wait_until "$show" "$run_secs"
get_now

# Announce start of scheduled command if running in foreground.
if [[ $show == 1 ]]; then
    echo -e "Started at $now_readable\n"
fi

# Run the scheduled command.
exec $to_run
