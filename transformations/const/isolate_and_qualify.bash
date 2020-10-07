#!/bin/bash

# @file transformations/const/isolate_and_qualify.bash
# @brief Isolate all variable declarations in LLVM first and then qualify
# all candidates with `const`.
#
# This code transformation for LLVM includes multiple steps and potential
# manual patching. Each stage is verified with `ninja check-all`.

: "${SOURCE_DIR:=/data/big/llvm-testing}"
: "${BINARY_DIR:=/data/big/dev-build}"
: "${TEST_BUILD:=/data/big/test-build}"

: "${CLANG_TIDY_LIB:=/data/big/clang-tidy-testing/src}"
: "${RUN_CLANG_TIDY:=${SOURCE_DIR}/clang-tools-extra/clang-tidy/tool/run-clang-tidy.py}"
: "${CLANG_TIDY:=${BINARY_DIR}/bin/clang-tidy}"

: "${GIT_TAG:=llvmorg-11.0.0-rc6}"
: "${BASE_REV:=$(cd ${SOURCE_DIR} && git checkout "${GIT_TAG}" > /dev/null 2>&1 && git rev-parse HEAD | cut -c -12)}"
: "${BRANCH_NAME:=transform_${BASE_REV}}"
: "${LOG_DIR:=/data/big/transformation/${BASE_REV}}"
: "${PROGRESS_DIR:=${LOG_DIR}}"

: "${TRANSFORM_DIRS:=lib/}"

shutdown() {
  # Get our process group id

  exit 1
}

trap "shutdown" SIGINT SIGTERM

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

if [ -z "${BASE_REV}" ] ; then
    die "BASE_REV revision could not be determined"
fi

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
    ninja check-all > "${LOG_DIR}/before_everything.log" 2> "${LOG_DIR}/before_everything.err" ||
        {
            log_error "Base-Revision is broken!"
            exit 1
        }
    return 0
}


transform_isolate_declarations() {
    log_info "Isolate Transformation"
    log_info "Check ${LOG_DIR}/isolate_decl.{log,err} for information on the execution."

    cd "${SOURCE_DIR}" || die "Can't switch into ${SOURCE_DIR}"
    run_clang_tidy_fix readability-isolate-declaration \
        -clang-apply-replacements-binary "${BINARY_DIR}/bin/clang-apply-replacements" \
        -p "${TEST_BUILD}" \
        ${TRANSFORM_DIRS} \
        > "${LOG_DIR}/isolate_decl.log" \
        2> "${LOG_DIR}/isolate_decl.err"

    log_info "Commiting automatic refactoring"
    git commit -am "[Refactor] automatically isolate all declarations"
    return 0
}


check_isolation() {
    log_info "Testing if build is still ok"
    cd "${TEST_BUILD}" || die "Can't switch into ${TEST_BUILD}"
    ninja
    ninja check-all > "${LOG_DIR}/test_after_isolation.log" 2> "${LOG_DIR}/test_after_isolation.err" ||
        {
            log_error "Isolating all Declaration causes test-breakage!"
            exit 1
        }
    return 0
}


transform_const() {
    log_info "Const Transformation"

    cd "${SOURCE_DIR}" || die "Can't switch into ${SOURCE_DIR}"
    run_clang_tidy_fix cppcoreguidelines-const-correctness \
        -clang-apply-replacements-binary "${BINARY_DIR}/bin/clang-apply-replacements" \
        -p "${TEST_BUILD}" \
        ${TRANSFORM_DIRS} \
        > "${LOG_DIR}/const-correctness.log" \
        2> "${LOG_DIR}/const-correctness.err"

    log_info "Commiting automatic refactoring"
    git commit -am "[Refactor] automatically declare everything const"

    return 0
}

fixup_const_transform() {
    log_info "Manual Patching of known issues"
    cd "${SOURCE_DIR}" || die "Can't switch into ${SOURCE_DIR}"
    patch -p1 < "${CLANG_TIDY_LIB}/../transformations/const/deduplication.patch" || die "Patch 1 does not apply"
    patch -p1 < "${CLANG_TIDY_LIB}/../transformations/const/mistakes.patch" || die "Patch 2 does not apply"
    patch -p1 < "${CLANG_TIDY_LIB}/../transformations/const/bad_transform.patch" || die "Patch 3 does not apply"
    git commit -am "[Fix] manual fixing of mistakes"
    return 0
}


check_const() {
    log_info "Testing if still runs"
    cd "${TEST_BUILD}" || die "Can't switch into ${TEST_BUILD}"
    ninja
    ninja check-all > "${LOG_DIR}/test_after_const.log" 2> "${LOG_DIR}/test_after_const.err" ||
        {
            log_error "Const Transformation causes test breakage!"
            exit 1
        }
    return 0
}

workstep test_initial check_initial_state

workstep isolation transform_isolate_declarations
workstep test_isolation check_isolation

workstep const transform_const
workstep fix_const fixup_const_transform
workstep test_const check_const

log_info "+++++++++++++++++++++++++++++++++++++++++++++++"
log_info "Transformation succeeded without code-breakage!"
log_info "+++++++++++++++++++++++++++++++++++++++++++++++"
