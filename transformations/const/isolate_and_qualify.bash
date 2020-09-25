#!/bin/bash

# @file transformations/const/isolate_and_qualify.bash
# @brief Isolate all variable declarations in LLVM first and then qualify
# all candidates with `const`.
#
# This code transformation for LLVM includes multiple steps and potential
# manual patching. Each stage is verified with `ninja check-all`.

: "${CLANG_TIDY_LIB:=/data/big/clang-tidy-testing/src}"
: "${RUN_CLANG_TIDY:=/data/big/llvm-project/clang-tools-extra/clang-tidy/tool/run-clang-tidy.py}"
: "${CLANG_TIDY:=/data/big/dev-build/bin/clang-tidy}"

: "${SOURCE_DIR:=/data/big/llvm-project}"
: "${BINARY_DIR:=/data/big/dev-build}"
: "${TEST_BUILD:=/data/big/test-build}"

: "${GIT_TAG:=llvmorg-11.0.0-rc3}"
: "${BASE_REV:=$(cd ${SOURCE_DIR} && git checkout "${GIT_TAG}" > /dev/null 2>&1 && git rev-parse HEAD | cut -c -12)}"
: "${BRANCH_NAME:=transform_${BASE_REV}}"
: "${LOG_DIR:=/data/big/transformation/${BASE_REV}}"

: "${TRANSFORM_DIRS:=clang/lib/Analysis}"

if [ ! -d "${LOG_DIR}" ] ; then
    mkdir -p "${LOG_DIR}"
fi

exec 3>> "${LOG_DIR}/const_transformation.log"
exec 4>> "${LOG_DIR}/const_transformation_debug.log"

# shellcheck disable=SC1090
source "${CLANG_TIDY_LIB}/util.bash" || exit 1
# shellcheck disable=SC1090
source "${CLANG_TIDY_LIB}/logging.bash" || die "Can not source logging"
# shellcheck disable=SC1090
source "${CLANG_TIDY_LIB}/workstep.bash" || die "Can not source worksteps"
# shellcheck disable=SC1090
source "${CLANG_TIDY_LIB}/run_clang_tidy.bash" || die "Can not source clang-tidy"


log_info "Create new branch from current revision ${BASE_REV}, called ${BRANCH_NAME}"
cd "${SOURCE_DIR}" || die "Can't switch into ${SOURCE_DIR}"

if GIT_STATUS=$(git status --porcelain) && [ -z "${GIT_STATUS}" ]; then
    git checkout "${BRANCH_NAME}" || git checkout -b "${BRANCH_NAME}"
else
    log_error "The git repository ${SOURCE_DIR} is not clean"
    log_error "${GIT_STATUS}"
    exit 1
fi


check_initial_state() {
    log_info "Test if everything is alright to start with"
    cd "${TEST_BUILD}" || die "Can't change into test directory"
    ninja clean
    ninja check-all > "${LOG_DIR}/before_everything.log" 2> "${LOG_DIR}/before_everything.err" ||
        {
            log_error "Base-Revision is broken!"
            exit 1
        }
}


transform_isolate_declarations() {
    log_info "Isolate Transformation"
    log_info "Check ${LOG_DIR}/isolate_decl.{log,err} for information on the execution."

    python2 "${RUN_CLANG_TIDY}" \
        -clang-tidy-binary "${BINARY_DIR}/bin/clang-tidy" \
        "-checks=-*,readability-isolate-declaration" \
        -fix \
        -p "${TEST_BUILD}" \
        -quiet \
        ${TRANSFORM_DIRS} > "${LOG_DIR}/isolate_decl.log" 2> "${LOG_DIR}/isolate_decl.err"

    log_info "Commiting automatic refactoring"
    cd "${SOURCE_DIR}" || die "Can't switch into ${SOURCE_DIR}"
    git commit -am "[Refactor] automatically isolate all declarations"
}


check_isolation() {
    log_info "Testing if build is still ok"
    cd "${TEST_BUILD}" || die "Can't switch into ${TEST_BUILD}"
    ninja clean
    ninja check-all > "${LOG_DIR}/test_after_isolation.log" 2> "${LOG_DIR}/test_after_isolation.err" ||
        {
            log_error "Isolating all Declaration causes test-breakage!"
            exit 1
        }
}


transform_const() {
    log_info "Const Transformation"
    python2 "${RUN_CLANG_TIDY}" \
        -clang-tidy-binary "${BINARY_DIR}/bin/clang-tidy" \
        "-checks=-*,cppcoreguidelines-const-correctness" \
        -fix \
        -p "${TEST_BUILD}" \
        -quiet \
        ${TRANSFORM_DIRS} > "${LOG_DIR}/const-correctness.log" 2> "${LOG_DIR}/const-correctness.err"

    log_info "Commiting automatic refactoring"
    cd "${SOURCE_DIR}" || die "Can't switch into ${SOURCE_DIR}"
    git commit -am "[Refactor] automatically declare everything const"
}


check_const() {
    log_info "Testing if still runs"
    cd "${TEST_BUILD}" || die "Can't switch into ${TEST_BUILD}"
    ninja clean
    ninja check-all > "${LOG_DIR}/test_after_const.log" 2> "${LOG_DIR}/test_after_const.err" ||
        {
            log_error "Const Transformation causes test breakage!"
            exit 1
        }
}

workstep test_initial check_initial_state

workstep isolation transform_isolate_declarations
workstep test_isolation check_isolation

workstep const transform_const
workstep test_const check_const
