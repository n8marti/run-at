# run-at
Bash script for scheduling commands

This script schedules a command or script to run at a later time.
It is similar in some ways to the "at" command, but there are also some important differences:
    a) commands are run with bash rather than sh;
    b) only one command is scheduled per run-at invocation;
    c) a countdown runs in the foreground by default, but there is an option for running the countdown in the background
