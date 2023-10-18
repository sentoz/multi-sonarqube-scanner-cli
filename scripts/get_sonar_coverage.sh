#!/usr/bin/env bash

# Wrapper for curl SonarQube
# shellcheck disable=SC2154
sq-api() {
  local path="$1"
  shift
  curl --location --fail "$debug_curl" --user "${SONARQUBE_TOKEN:-}:" \
    "${SONARQUBE_URL:-}/api/$path" "${@}"
}

coverage=$(
  sq-api measures/component \
    -d "component=$SONARQUBE_PROJECT_KEY" \
    -d "metricKeys=coverage" \
    -d "${coverage_reference:-}" |
    jq -er '.component.measures[] | select(.metric == "coverage") | .value' || :
)

if [ -n "$coverage" ]; then
  info "SonarQube coverage $coverage%"
else
  warn 'SonarQube coverage was not received'
fi
