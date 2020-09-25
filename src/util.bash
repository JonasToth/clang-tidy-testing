#!/bin/bash

# @file util.bash Provide common functions used everywhere.

# Stop the execution of the script immediatly and print an error
die() {
    echo "$@" >&2
    exit 1
}
