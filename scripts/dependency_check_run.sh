#!/usr/bin/env bash

# Variables
# -----------------------------------------------------------------------------
# OWASP Dependency Check
: "${OWASP_DEPENDENCY_CHECK_SUPPRESSIONS_FILE_PATH:=$PROJECT_DIR/suppression.xml}"
: "${OWASP_DEPENDENCY_CHECK_DISABLE_OSS_INDEX:=true}"
: "${OWASP_DEPENDENCY_CHECK_NVD_VALID_HOURS:=24}"
: "${OWASP_DEPENDENCY_CHECK_DB_DRIVER:-}"
# Version of analyzed project
version="${REF_NAME:-MR-${MERGE_REQUEST_ID:-0}}"
# Create empty array of arguments for dependency check
dc_args=()

# Disable OSS Index
if is-true "$OWASP_DEPENDENCY_CHECK_DISABLE_OSS_INDEX"; then
  dc_args+=(
    "--disableOssIndex"
  )
else
  if [ -n "${OWASP_DEPENDENCY_CHECK_OSS_INDEX_USERNAME:-}" ] &&
    [ -n "${OWASP_DEPENDENCY_CHECK_OSS_INDEX_PASSWORD:-}" ]; then
    dc_args+=(
      --ossIndexUsername "$OWASP_DEPENDENCY_CHECK_OSS_INDEX_USERNAME"
      --ossIndexPassword "$OWASP_DEPENDENCY_CHECK_OSS_INDEX_PASSWORD"
    )
  else
    warn 'You not set variable OWASP_DEPENDENCY_CHECK_OSS_INDEX_USERNAME and' \
      ' OWASP_DEPENDENCY_CHECK_OSS_INDEX_PASSWORD, you will use the default' \
      'rate limits.'
  fi
fi

# Use database server

if [ -n "${OWASP_DEPENDENCY_CHECK_DB_DRIVER:-}" ] &&
  [ -n "${OWASP_DEPENDENCY_CHECK_DB_STRING:-}" ] &&
  [ -n "${OWASP_DEPENDENCY_CHECK_DB_PASSWORD:-}" ] &&
  [ -n "${OWASP_DEPENDENCY_CHECK_DB_USER:-}" ]; then
  info 'You use database server for perform analysis'
  dc_args+=(
    --dbDriverName="$OWASP_DEPENDENCY_CHECK_DB_DRIVER"
    --connectionString "$OWASP_DEPENDENCY_CHECK_DB_STRING"
    --dbPassword "$OWASP_DEPENDENCY_CHECK_DB_PASSWORD"
    --dbUser "$OWASP_DEPENDENCY_CHECK_DB_USER"
    --nvdValidForHours "$OWASP_DEPENDENCY_CHECK_NVD_VALID_HOURS"
    --noupdate
  )
else
  warn 'You do not use central database. For used, set variables' \
    'OWASP_DEPENDENCY_CHECK_DB_DRIVER, OWASP_DEPENDENCY_CHECK_DB_STRING,' \
    'OWASP_DEPENDENCY_CHECK_DB_PASSWORD and OWASP_DEPENDENCY_CHECK_DB_USER.' \
    'Most informations' \
    'https://jeremylong.github.io/DependencyCheck/dependency-check-cli/arguments.html'
fi

# Suppression file use if exist
[ -f "$OWASP_DEPENDENCY_CHECK_SUPPRESSIONS_FILE_PATH" ] &&
  dc_args+=(
    --suppression "$OWASP_DEPENDENCY_CHECK_SUPPRESSIONS_FILE_PATH"
  )

# If no skip sonarqube scanner
if ! is-true "$SKIP_SONARQUBE_SCANNER_JOB"; then
  dc_args+=(
    --project "$SONARQUBE_PROJECT_NAME:$version ($SONARQUBE_PROJECT_KEY)"
  )
fi

dc_log_name="dependency-check-$PROJECT_NAME-$COMMIT_REF_SLUG.log"
# shellcheck disable=SC2154
$debug_sh /opt/dependency-check/bin/dependency-check.sh \
  --out "$PROJECT_DIR" \
  --scan "$PROJECT_DIR" \
  --format JSON \
  --format HTML \
  --enableExperimental \
  --log "$PROJECT_DIR/$dc_log_name" \
  "${dc_args[@]}" || \
  __e_dc=1 warn "Error run DependencyCheck analyzing, $SUPPORT_CONTACTS"

info "For more details, check the analyzer log in the ./$dc_log_name file"
