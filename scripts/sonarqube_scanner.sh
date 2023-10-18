#!/usr/bin/env bash

# SonarQube Scanner Args
# -----------------------------------------------------------------------------
# Set key prefix for SonarScanner arguments by type
if command -v dotnet &>/dev/null; then
  key_prefix=/d:
  sq_key=/d:sonar
  project_type=dotnet
  SONARQUBE_VERBOSE=true
elif command -v gradle &>/dev/null; then
  key_prefix=-D:
  sq_key=-Dsonar
  project_type=gradle
else
  key_prefix=-D
  sq_key=-Dsonar
  project_type=simple
fi

# Default array of arguments for SonarScanner
sq_args=(
  "$sq_key.qualitygate.wait=$SONARQUBE_QUALITYGATE_WAIT"
  "$sq_key.qualitygate.timeout=$SONARQUBE_QUALITYGATE_TIMEOUT"
  "$sq_key.links.homepage=$PROJECT_URL"
  "$sq_key.links.ci=$PROJECT_URL/-/pipelines"
  "$sq_key.links.issue=$PROJECT_URL/-/issues"
  "$sq_key.links.scm=$PROJECT_URL/-/tree/$DEFAULT_BRANCH"
  "$sq_key.host.url=$SONARQUBE_URL"
  "$sq_key.login=$SONARQUBE_TOKEN"
  "$sq_key.log.level=${SONARQUBE_LOG_LEVEL^^}"
  "$sq_key.verbose=$SONARQUBE_VERBOSE"
  "$sq_key.python.version=${SONARQUBE_PYTHON_VERSION:-3}"
)

# Additional DependencyCheck arguments for SonarScanner
if ! is-true "$SKIP_DEPENDENCY_CHECK_JOB"; then
  dc_report=dependency-check-report
  dc_key="$sq_key.dependencyCheck"
  sq_args+=(
    "$dc_key.severity.blocker=${OWASP_DEPENDENCY_CHECK_SEVERITY_BLOCKER:-9.0}"
    "$dc_key.severity.critical=${OWASP_DEPENDENCY_CHECK_SEVERITY_CRITICAL:-7.0}"
    "$dc_key.severity.major=${OWASP_DEPENDENCY_CHECK_SEVERITY_MAJOR:-4.0}"
    "$dc_key.severity.minor=${OWASP_DEPENDENCY_CHECK_SEVERITY_MINOR:-0.0}"
    "$dc_key.jsonReportPath=$PROJECT_DIR/$dc_report.json"
    "$dc_key.htmlReportPath=$PROJECT_DIR/$dc_report.html"
  )
fi

# Import Generic Issue reports.
if [ -f "$SONARQUBE_GENERIC_REPORTS_FILE" ]; then
  sq_args+=("$sq_key.externalIssuesReportPaths=$SONARQUBE_GENERIC_REPORTS_FILE")
fi

# Specify arguments for Merge Request analyze
# shellcheck disable=SC2034
if [ "${CI_PIPELINE_SOURCE:-}" == 'merge_request_event' ]; then
  sq_args+=(
    "$sq_key.pullrequest.key=${CI_MERGE_REQUEST_IID:-}"
    "$sq_key.pullrequest.branch=${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME:-}"
    "$sq_key.pullrequest.base=${CI_MERGE_REQUEST_TARGET_BRANCH_NAME:-}"
  )
  coverage_reference="pullRequest=${MERGE_REQUEST_ID:-}"

# Specify arguments for tag analyze
elif [ -n "${COMMIT_TAG:-}" ]; then
  if [ "$project_type" == 'dotnet' ]; then
    sq_args+=("/v:$COMMIT_TAG")
  else
    sq_args+=("$sq_key.projectVersion=$COMMIT_TAG")
  fi
  sq_args+=("$sq_key.branch.name=$COMMIT_TAG")
  coverage_reference="branch=$COMMIT_TAG"

# Set args for branch analyze
elif [ -n "${COMMIT_BRANCH:-}" ]; then
  sq_args+=("$sq_key.branch.name=$COMMIT_BRANCH")
  coverage_reference="branch=$COMMIT_BRANCH"
fi

# Add custom user defined args
if [ -n "${SONARQUBE_CUSTOM_ARGS:-}" ]; then
  for carg in ${SONARQUBE_CUSTOM_ARGS//,/ }; do
    sq_args+=("$key_prefix$carg")
  done
fi

# Running the SonarQube Scanner
# -----------------------------------------------------------------------------

# Run SonarQube Scanner for .Net project with build and tests
if [ "$project_type" == 'dotnet' ]; then
  # shellcheck disable=SC1091
  source /usr/bin/scripts/sonar_scan_dotnet.sh

# Running the SonarQube Scanner for Gradle project without tests
elif [ "$project_type" == 'gradle' ]; then

  section-start 'scanner' "Run SonarQube scanner for Gradle"

  gradle --no-daemon --parallel sonarqube -i -x test \
    -x compileJava -x compileTestJava \
    $sq_key.projectKey="$SONARQUBE_PROJECT_KEY" \
    $sq_key.projectName="$SONARQUBE_PROJECT_NAME" \
    $sq_key.java.binaries=src/* \
    $sq_key.coverage.jacoco.xmlReportPaths=build/jacoco.xml \
    $sq_key.core.codeCoveragePlugin="jacoco" \
    "${sq_args[@]}" || __e_sq=1

  section-end
# Running the SonarQube Scanner natively
else

  section-start 'scanner' "Run SonarQube scanner"

  sonar-scanner \
    $sq_key.projectKey="$SONARQUBE_PROJECT_KEY" \
    $sq_key.projectName="$SONARQUBE_PROJECT_NAME" \
    "${sq_args[@]}" || __e_sq=1

  section-end
fi
