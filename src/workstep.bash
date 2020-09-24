#!/bin/bash

# @filename workstep.bash
# @brief Helper to define an atomic work step that can be skipped.
#
# This file provides functionality to have worksteps in a skippable manner.
# It is based on hidden files whose existence indicates the step is done.

# @brief If necessary, call a function and create a 'done' file on success.
#
# @param step_name Unique identifier, must be non-empty, only letters
# @param function_to_call bash-function that is called if workstep has to be
#                         done
#
# @precondition Define '${PROGRESS_DIR}' to a directory that stores the .dot
#               files.
#               If '${PROGRESS_DIR}' is empty, it will be the current directory.
# @postcondition 
workstep() {
    step_name="${1}"
    if [ -z "${step_name}" ] ; then
        die "Name of workstep can not be empty"
    fi
    if [[ ! ${step_name} =~ ^[a-zA-Z_]+$ ]] ; then
        die "Only letters for step_name allowed (provided '${step_name}')"
    fi

    function_to_call="${2}"
    if [ -z "${function_to_call}" ] ; then
        die "Function to call empty!"
    fi

    step_file="${PROGRESS_DIR:="."}/.${step_name}"

    if [ -e "${step_file}" ] && [ ! -f "${step_file}" ] ; then
        die "${step_file} exists, but not as classical file. Aborting!"
    fi

    # If the step has not been executed, do so.
    if [ ! -f "${step_file}" ] ; then
        ${function_to_call}
        function_return=$?

        if [ "${function_return}" -eq 0 ]; then
            touch "${step_file}" || die "Could not create step file"
        fi

        return ${function_return}
    fi

    return 0
}

# This section contains unit tests for the provided function.
# In production this file would be sourced to make the function available.
# Doing `bash workstep.bash` on the other hand executes these tests.
(return 0 2>/dev/null) && sourced=1 || sourced=0

if [ "${sourced}" -eq 0 ] ; then

die() {
    echo "- Dying: $*"
    exit 1
}

cleanup() {
    rmdir ".test_directory_for_workstep"
    rm -f ".execute_echo" ".test_run" ".hustling" ".failing"
    rm -rf ".progress"
}
trap "cleanup" EXIT

    echo "+ Running unit tests for this file!"
    echo

    if (workstep "") ; then
        echo "! Failed 'die' for empty argument"
        exit 1
    else
        echo "* Empty string properly rejected"
    fi

    if (workstep "step_with_number42") ; then
        echo "! Failed to 'die' for bad work_step name"
        exit 1
    else
        echo "* Number in string properly rejected"
    fi

    if (workstep ".with_point") ; then
        echo "! Failed to 'die' for workstep name starting with a point"
        exit 1
    else
        echo "* dot in string properly rejected"
    fi

    if (workstep "no_function") ; then
        echo "! Failed to 'die' for workstep without function"
        exit 1
    else
        echo "* empty function call properly rejected"
    fi

    if ! (workstep "test_run" "echo 'Foo'") ; then
        echo "! Failed to run proper work_step test"
        exit 1
    else
        echo "* properly run valid workstep"
    fi

    mkdir -p ".test_directory_for_workstep"
    if (workstep "test_directory_for_workstep" "echo 'Foo'") ; then
        echo "! Failed to detect existing directory"
        exit 1
    else
        echo "* properly rejected stepfile that exists as something else"
    fi

    touch ".execute_echo"
    (workstep "execute_echo" "echo 'Foo'; touch .echo_done")
    if [ -e ".echo_done" ] ; then
        echo "! Failed to skip step whose skip-file existed"
        exit 1
    else
        echo "* properly skipped step that was done already"
    fi

    if ! (workstep "hustling" "echo 'Really hustling'") ; then
        echo "! Proper workstep did not return 0"
        exit 1
    fi
    if [ ! -e ".hustling" ] ; then
        echo "! Stepfile not created for proper workstep"
        exit 1
    else
        echo "* properly creating workstep file"
    fi

    (workstep "hustling" "touch .hustling_again")
    if [ -e ".hustling_again" ] ; then
        echo "! Function executed despite stepfile"
        exit 1
    else
        echo "* properly skipped step"
    fi

    if ! workstep "failing" "false" ; then
        echo "* Properly transfer return value of callback function"

        if [ -e ".failing" ]; then
            echo "! Creating stepfile for failing function"
            exit 1
        else
            echo "* correctly not creating a stepfile for failing function"
        fi
    else
        echo "! Failing callback must result in falling workstep"
        exit 1
    fi

    PROGRESS_DIR=".progress"
    mkdir "${PROGRESS_DIR}"

    if ! workstep "first_one" "true" ; then
        echo "! fail to execute first trivial step "
        exit 1
    fi
    if [ ! -e ".progress/.first_one" ] ; then
        echo "! expected stepfile not existing in progressdir"
        exit 1
    fi
    if workstep "second_one" "false" ; then
        echo "! fail to reject trivial failing step"
        exit 1
    fi
    if [ -e ".progress/.second_one" ] ; then
        echo "! second step file is not allowed to exist"
        exit 1
    fi

    echo
    echo "+ All tests successfull!"
    exit 0
fi
