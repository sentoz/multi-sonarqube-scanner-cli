#!/usr/bin/env bash

# For sync permissions used project https://github.com/WoozyMasta/guassp
# shellcheck disable=SC2154
curl --location --fail "$debug_curl" --header "JOB-TOKEN: ${JOB_TOKEN:-}" \
  -X POST "$SONARQUBE_URL/api/guassp/task" | jq -e
