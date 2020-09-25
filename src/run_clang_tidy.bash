#!/bin/bash

# @filename run_clang_tidy.bash
# @brief Provides function to run clang-tidy for a project.

# @brief Helper function to call 'run-clang-tidy'.
#
# This function can be parametrized with setting
# ${RUN_CLANG_TIDY} to a path to the run-clang-tidy script
# and setting ${CLANG_TIDY} to the clang-tidy executable
# that shall be used.
__execute_run_clang_tidy() {
    if [ -n "${RUN_CLANG_TIDY}" ] ; then
        [ -x "${RUN_CLANG_TIDY}" ] || die "${RUN_CLANG_TIDY} must be executable run-clang-tidy script"
    fi
    if [ -n "${CLANG_TIDY}" ] ; then
        [ -x "${CLANG_TIDY}" ] || die "${CLANG_TIDY} must be clang-tidy executable"
    fi

    "${RUN_CLANG_TIDY:-run-clang-tidy.py}" \
        -clang-tidy-binary "${CLANG_TIDY:-clang-tidy}" \
        "$@"
    return $?
}

# @brief Use ${RUN_CLANG_TIDY} in ${SRC_DIR}.
#
# The function wraps the execution of run-clang-tidy and
# provides some customization points to control the behaviour.
#
# @param checks String controlling the checks to be enabled.
#               All other checks are disabled!
# @param files All following arguments are passed as files to be analyzed.
run_clang_tidy() {
    local checks="$1"
    shift
    __execute_run_clang_tidy -checks="-*,${checks}" "$@"
    return $?
}

# @brief Use ${RUN_CLANG_TIDY} in ${SRC_DIR} and apply fixes, too.
# @note Same arguments as 'run_clang_tidy'
run_clang_tidy_fix() {
    local checks="$1"
    shift
    __execute_run_clang_tidy -fix -checks="-*,${checks}" "$@"
    return $?
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
    rm -f mock_run_clang_tidy
    rm -f mock_run_clang_tidy2
    rm -f mock_clang_tidy
}
trap "cleanup" EXIT

    echo
    echo "+ Running unit tests for $0!"
    echo

    RUN_CLANG_TIDY="bad-call"
    CLANG_TIDY="clang-tidy"
    if (__execute_run_clang_tidy) ; then
        echo "! Failed to 'die' on bad run-clang-tidy executable"
        exit 1
    else
        echo "* Properly tested run-clang-tidy script"
    fi

    cat > mock_run_clang_tidy << EOF
#!/bin/bash
echo "Mocking run-clang-tidy"
exit 0
EOF
    chmod +x mock_run_clang_tidy
    RUN_CLANG_TIDY="mock_run_clang_tidy"
    CLANG_TIDY="bad_clang-tidy"
    if (__execute_run_clang_tidy) ; then
        echo "! Failed to 'die' on bad clang-tidy executable"
        exit 1
    else
        echo "* Properly tested clang-tidy executable"
    fi

    cat > mock_run_clang_tidy2 << EOF
#!/bin/bash
\$2 \$3
EOF
    cat > mock_clang_tidy << EOF
#!/bin/bash
echo \$1
EOF
    chmod +x mock_run_clang_tidy2 mock_clang_tidy

    RUN_CLANG_TIDY="./mock_run_clang_tidy2"
    CLANG_TIDY="./mock_clang_tidy"
    if output=$(__execute_run_clang_tidy "Hello") && [ "${output}" != "Hello" ] ; then
        echo "! Failed to properly execute clang-tidy mocks with arguments"
        exit 1
    else
        echo "* Proper clang-tidy execution observed"
    fi

    echo
    echo "+ All tests successfull!"
    exit 0
fi
