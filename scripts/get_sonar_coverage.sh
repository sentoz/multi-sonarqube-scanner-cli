#!/usr/bin/env bash

# Wrapper for curl SonarQube
# shellcheck disable=SC2154
sq-api() {
  local path="$1"
  shift
  curl --location --fail "$debug_curl" --user "${SONARQUBE_TOKEN:-}:" \
    "${SONARQUBE_URL:-}/api/$path" "${@}"
}

# Encode url symbols
urlencode() {
  local LC_COLLATE=C length="${#1}"
  for ((i = 0; i < length; i++)); do
    local c="${1:$i:1}"
    case $c in
      [a-zA-Z0-9.~_-]) printf '%s' "$c" ;;
                    *) printf '%%%02X' "'$c" ;;
    esac
  done
}

coverage=$(
  sq-api \
    "measures/component?component=$(urlencode "$SONARQUBE_PROJECT_KEY")&metricKeys=coverage&${coverage_reference:-}" |
    jq -er '.component.measures[] | select(.metric == "coverage") | .value' || :
)

if [ -n "$coverage" ]; then
  info "SonarQube coverage $coverage%"
else
  warn 'SonarQube coverage was not received'
fi
