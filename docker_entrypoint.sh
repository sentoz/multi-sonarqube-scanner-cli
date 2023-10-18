#!/usr/bin/env bash

set -euo pipefail

: "${DEBUG:=${CI_DEBUG_TRACE:=${ACTIONS_RUNNER_DEBUG:=false}}}"
if [ "$DEBUG" == 'true' ]; then
  set -x
  debug_sh="sh -x"
  debug_curl=--verbose
  SONARQUBE_LOG_LEVEL=DEBUG
else
  # shellcheck disable=SC2034
  debug_sh='sh'
  # shellcheck disable=SC2034
  debug_curl=--silent
fi

# Functions
# -----------------------------------------------------------------------------
# Log separator
section-start() {
  section="${1//[-_\. ]/_}"
  shift
  printf '\e[0Ksection_start:%s:%s[collapsed=true]\r\e[0K\e[1;36m%s\e[0m\n' \
    "$(date +%s)" "$section" "$*"
}
section-end() {
  printf '\e[0Ksection_end:%s:%s\r\e[0K\n' "$(date +%s)" "${section:-}"
  section=''
}

# Messages
fail() {
  section-end
  printf >&2 '\e[1;31m%s\e[0m\n' "$*"
  exit 1
}
warn() { printf >&2 '\e[1;33m%s\e[0m\n' "$*"; }
info() { printf '\e[1;34m%s\e[0m\n' "$*"; }

# Check string is boolean True
is-true() {
  grep --perl-regexp --ignore-case --quiet '^(true|on|yes|1)$' <<<"$1"
}

# Global  variables
# -----------------------------------------------------------------------------
# Determine the type of launch
if [ "${GITHUB_ACTIONS:-}" == 'true' ]; then
  # Otherwise, if we are working in GitHub Action, then we will execute the
  # script.
  info "Run SonarQube Scanner for ${GITHUB_REPOSITORY:-undefined} project"

  # Prepare variables
  : "${SONARQUBE_PROJECT_NAME:=$GITHUB_REPOSITORY}"
  : "${SONARQUBE_PROJECT_KEY:=${GITHUB_REPOSITORY#*/}}"
  : "${DEFAULT_BRANCH:=$GITHUB_BASE_REF}"
  : "${COMMIT_BRANCH:=$GITHUB_REF_NAME}"
  : "${PROJECT:-}"
  : "${JOB_TOKEN:=$GITHUB_TOKEN}"
  : "${PROJECT_DIR:=$GITHUB_WORKSPACE}"
  : "${REF_NAME:=$GITHUB_REF_NAME}"
  : "${MERGE_REQUEST_ID:=$GITHUB_RUN_ID}"
  : "${COMMIT_REF_SLUG:=$GITHUB_REF_NAME}"
  : "${PROJECT_NAME:=${GITHUB_REPOSITORY#*/}}"
  : "${PROJECT_URL:=$GITHUB_SERVER_URL/$GITHUB_REPOSITORY}"

  [ "${GITHUB_REF_TYPE:-}" == 'tag' ] &&
    COMMIT_TAG="${GITHUB_REF#"refs/tags/"}"

elif [ "${GITLAB_CI:-}" == 'true' ]; then
  # Otherwise, if we are working in GitLab CI, then we will execute the script.
  info "Run SonarQube Scanner for ${CI_PROJECT_TITLE:-undefined} project"

  # Prepare variables
  : "${SONARQUBE_PROJECT_NAME:=$CI_PROJECT_NAMESPACE/$CI_PROJECT_NAME}"
  : "${SONARQUBE_PROJECT_KEY:=gitlab:$CI_PROJECT_ID}"
  : "${DEFAULT_BRANCH:=$CI_DEFAULT_BRANCH}"
  : "${COMMIT_BRANCH:=$CI_COMMIT_BRANCH}"
  : "${COMMIT_TAG:=${CI_COMMIT_TAG:-}}"
  : "${PROJECT:=$CI_PROJECT_ID}"
  : "${JOB_TOKEN:=$CI_JOB_TOKEN}"
  : "${PROJECT_DIR:=$CI_PROJECT_DIR}"
  : "${REF_NAME:=$CI_COMMIT_REF_NAME}"
  : "${MERGE_REQUEST_ID:=${CI_MERGE_REQUEST_IID:-}}"
  : "${PROJECT_NAME:=$CI_PROJECT_NAME}"
  : "${COMMIT_REF_SLUG:=$CI_COMMIT_REF_SLUG}"
  : "${SONARQUBE_ALM_NAME:=GitLab}"
  : "${JOB_TOKEN:=$CI_JOB_TOKEN}"
  : "${PROJECT_URL:=$CI_PROJECT_URL}"

else
  # Otherwise, just run sonar-scanner
  sonar-scanner
  exit 0
fi

# Default variables
# -----------------------------------------------------------------------------
# SonarQube
: "${SONARQUBE_URL?SonarQube sonarqube server root url not specified}"
: "${SONARQUBE_TOKEN?Token for connecting to the SonarQube was not specified}"
: "${SONARQUBE_QUALITYGATE_WAIT:=true}"
: "${SONARQUBE_QUALITYGATE_TIMEOUT:=300}"
: "${SONARQUBE_LOG_LEVEL:=INFO}"
: "${SONARQUBE_VERBOSE:=false}"
: "${SONARQUBE_ALOW_FAILURE:=true}"
: "${SONARQUBE_GENERIC_REPORTS_FILE:=$PROJECT_DIR/issues.json}"
# Skip stages
: "${SKIP_DEPENDENCY_CHECK_JOB:=false}"
: "${SKIP_SONARQUBE_PREPARE:=false}"
: "${SKIP_SONARQUBE_SCANNER_JOB:=false}"
: "${SKIP_SONARQUBE_COVERAGE:=false}"
: "${SKIP_SONARQUBE_PERMISSIONS_SYNC:=false}"
# Feedback contact
: "${SUPPORT_CONTACTS:="https://github.com/sentoz/multi-sonarqube-scanner-cli/issues"}"

#
if ! is-true "$SKIP_SONARQUBE_PREPARE" &&
  [ "${GITLAB_CI:-}" == 'true' ]; then
  section-start prepare 'Preparing to run the SonarQube Scanner'
  # shellcheck disable=SC1091
  source /usr/bin/scripts/prepare.sh
  section-end
elif is-true "$SKIP_SONARQUBE_PREPARE" &&
  [ "${GITLAB_CI:-}" == 'true' ]; then
  warn 'Preparing SonarQube skiped by flag SKIP_SONARQUBE_PREPARE=true'
else
  warn 'Preparing SonarQube supported only Gitlab CI'
fi

if ! is-true "$SKIP_SONARQUBE_PERMISSIONS_SYNC" &&
  [ "${GITLAB_CI:-}" == 'true' ]; then
  section-start 'guassp' "SonarQube project users access sync with GitLab"
  # shellcheck disable=SC1091
  source /usr/bin/scripts/permissions_sync.sh
  section-end
elif is-true "$SKIP_SONARQUBE_PERMISSIONS_SYNC" &&
  [ "${GITLAB_CI:-}" == 'true' ]; then
  warn 'SonarQube project access sync skiped by flag' \
    'SKIP_SONARQUBE_PERMISSIONS_SYNC=true'
else
  warn 'SonarQube project access sync supported only Gitlab CI'
fi

if ! is-true "$SKIP_DEPENDENCY_CHECK_JOB"; then
  section-start 'dependency' 'Analyzing dependencies with DependencyCheck'
  # shellcheck disable=SC1091
  source /usr/bin/scripts/dependency_check_run.sh
  section-end
else
  warn 'DependencyCheck analyzing skiped by flag SKIP_DEPENDENCY_CHECK_JOB=true'
fi

if ! is-true "$SKIP_SONARQUBE_SCANNER_JOB"; then
  # shellcheck disable=SC1091
  source /usr/bin/scripts/sonarqube_scanner.sh
else
  warn 'SonarQube Scanner skiped by flag SKIP_SONARQUBE_SCANNER_JOB=true'
fi

if ! is-true "$SKIP_SONARQUBE_COVERAGE"; then
  section-start 'coverage' "Get code coverage from SonarQube"
  # shellcheck disable=SC1091
  source /usr/bin/scripts/get_sonar_coverage.sh
  section-end
else
  warn 'SonarQube coverage request skiped by flag SKIP_SONARQUBE_COVERAGE=true'
fi

if [ ${__e_dotnet:-0} -eq 1 ]; then
  fail "Dotnet build failed, see log above."
elif [ ${__e_test:-0} -eq 1 ]; then
  fail "DotnetTest failed, see log above."
elif [ ${__e_sq:-0} -eq 1 ] && ! is-true "$SONARQUBE_ALOW_FAILURE"; then
  fail "SonarQube scan failed, see log above."
elif [ "${__e_dc:-0}" -eq 1 ] && ! is-true "$SONARQUBE_ALOW_FAILURE"; then
  fail "DependencyCheck failed, see log above."
fi
