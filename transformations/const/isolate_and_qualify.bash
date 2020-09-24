#!/bin/bash

# @file transformations/const/isolate_and_qualify.bash
# @brief Isolate all variable declarations in LLVM first and then qualify
# all candidates with `const`.
#
# This code transformation for LLVM includes multiple steps and potential
# manual patching. Each stage is verified with `ninja check-all`.

: ${SOURCE_DIR:="/data/big/llvm-project"}
: ${BINARY_DIR:="/data/big/dev-build"}
: ${TEST_BUILD:="/data/big/test-build"}
: ${RUN_CLANG_TIDY:="/data/big/llvm-project/clang-tools-extra/clang-tidy/tool/run-clang-tidy.py"}

: ${GIT_TAG:="llvmorg-11.0.0-rc3"}
: ${BASE_REV:="$(cd ${SOURCE_DIR} && git checkout "${GIT_TAG}" > /dev/null 2>&1 && git rev-parse HEAD | cut -c -12)"}
: ${BRANCH_NAME:="transform_${BASE_REV}"}
: ${LOG_DIR:="/data/big/transformation/${BASE_REV}"}

: ${TRANSFORM_DIRS:="clang/lib/Analysis"}
: ${JOBS:="-j 18"}

if [ ! -d "${LOG_DIR}" ] ; then
    mkdir -p "${LOG_DIR}"
fi

exec 3>> "${LOG_DIR}/const_transformation.log"
exec 4>> "${LOG_DIR}/const_transformation_debug.log"

source "$(dirname ${0})/logging.bash"

log_info "================================================================"
log_info "Testing the log"
debug "Testing the debug"

exit 0

log_info "Create new branch from current revision ${BASE_REV}, called ${BRANCH_NAME}"
cd "${SOURCE_DIR}"

if GIT_STATUS=$(git status --porcelain) && [ -z "${GIT_STATUS}" ]; then
    git checkout "${BRANCH_NAME}" || git checkout -b "${BRANCH_NAME}"
else
    log_error "The git repository ${SOURCE_DIR} is not clean"
    log_error "${GIT_STATUS}"
    exit 1
fi


log_info "Test if everything is alright to start with"
if [ ! -f "${LOG_DIR}/.base" ] ; then
    cd "${TEST_BUILD}"
    ninja clean
    ninja ${JOBS} check-all > "${LOG_DIR}/before_everything.log" 2> "${LOG_DIR}/before_everything.err" ||
        {
            log_error "Base-Revision is broken!"
            exit 1
        }
    touch "${LOG_DIR}/.base"
else
    log_info "Stage already done"
fi


log_info "Isolate Transformation"
log_info "Check ${LOG_DIR}/isolate_decl.{log,err} for information on the execution."
if [ ! -f "${LOG_DIR}/.isolation" ] ; then
    python2 "${RUN_CLANG_TIDY}" \
        -clang-tidy-binary "${BINARY_DIR}/bin/clang-tidy" \
        "-checks=-*,readability-isolate-declaration" \
        -fix \
        ${JOBS} \
        -p "${TEST_BUILD}" \
        -quiet \
        ${TRANSFORM_DIRS} > "${LOG_DIR}/isolate_decl.log" 2> "${LOG_DIR}/isolate_decl.err"

    log_info "Commiting automatic refactoring"
    cd "${SOURCE_DIR}"
    git commit -am "[Refactor] automatically isolate all declarations"
    touch "${LOG_DIR}/.isolation"
else
    log_info "Isolation already done"
fi


log_info "Testing if build is still ok"
if [ ! -f "${LOG_DIR}/.test_isolation" ] ; then
    cd "${TEST_BUILD}"
    ninja clean
    ninja ${JOBS} check-all > "${LOG_DIR}/test_after_isolation.log" 2> "${LOG_DIR}/test_after_isolation.err" ||
        {
            log_error "Isolating all Declaration causes test-breakage!"
            exit 1
        }
    touch "${LOG_DIR}/.test_isolation"
else
    log_info "Testing after isolation done"
fi


log_info "Const Transformation"
if [ ! -f "${LOG_DIR}/.const_transformation" ] ; then
    python2 "${RUN_CLANG_TIDY}" \
        -clang-tidy-binary "${BINARY_DIR}/bin/clang-tidy" \
        "-checks=-*,cppcoreguidelines-const-correctness" \
        -fix \
        ${JOBS} \
        -p "${TEST_BUILD}" \
        -quiet \
        ${TRANSFORM_DIRS} > "${LOG_DIR}/const-correctness.log" 2> "${LOG_DIR}/const-correctness.err"

    log_info "Commiting automatic refactoring"
    cd "${SOURCE_DIR}"
    git commit -am "[Refactor] automatically declare everything const"
    touch "${LOG_DIR}/.const_transformation"
else
    log_info "Const Transformation already done"
fi


log_info "Testing if still runs"
if [ ! -f "${LOG_DIR}/.const_test" ] ; then
    cd "${TEST_BUILD}"
    ninja clean
    ninja ${JOBS} check-all > "${LOG_DIR}/test_after_const.log" 2> "${LOG_DIR}/test_after_const.err" ||
        {
            log_error "Const Transformation causes test breakage!"
            exit 1
        }
    touch "${LOG_DIR}/.const_test"
else
    log_info "Const Transformation test done"
fi
