#!/bin/bash

# @file logging.bash
# @brief Provide logging primitives for all functions and scripts to use.
#
# This file provides basic logging functions, that produce structured logs
# with timestamps and markers for severity.
#
# Each `log_*` message is written to the filedescriptor '3', that needs to be
# created in the main script with
# ```bash
# # Write into file and potentially overwrite.
# exec 3> /path/to/logfile
# # Append to file and don't overwrite.
# exec 3>> /path/to/logfile
# ```
# Close this channel with `exec 3>&-` if no further logging is to be done.
#
# `debug()` writes into '4', for which the same applies as for the log
# descriptor.

# @brief Write a message to stdout (fd '1').
stdout() {
    echo "$@"
}

# @brief Write a message to stderr (fd '2').
stderr() {
    echo "$@" >&2
}

# @brief Write an info message into the log filedescriptor (fd '3').
log_info() {
    echo "* $(date +"%d.%m.%Y %H:%M:%S")  INFO: $*" >&3
}

# @brief Write a warning message into the log filedescriptor (fd '3').
log_warn() {
    echo "! $(date +"%d.%m.%Y %H:%M:%S")  WARN: $*" >&3
}

# @brief Write an error message into the log filedescriptor (fd '3').
log_error() {
    echo "! $(date +"%d.%m.%Y %H:%M:%S") ERROR: $*" >&3
}

# @brief This function writes any message into filedescriptor '4' for debugging
# purposes.
debug() {
    echo "*  $(date +"%d.%m.%Y %H:%M:%S") ERROR: $*" >&4
}
