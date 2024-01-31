#!/usr/bin/env bash

# Wrapper for curl SonarQube
# shellcheck disable=SC2154
sq-api() {
  local path="$1"
  shift
  curl --location --fail "$debug_curl" --user "${SONARQUBE_TOKEN:-}:" \
    "${SONARQUBE_URL:-}/api/$path" "${@}"
}

# Version of analyzed project
version="${REF_NAME:-MR-${MERGE_REQUEST_ID:-0}}"
# Check default branch name
# Get branches list data
sq_branches="$(
  sq-api project_branches/list?project="$SONARQUBE_PROJECT_KEY" ||
    echo '{}'
)"

# Checking if a project exists in a SQ
if ! jq -er '.branches[]' <<<"$sq_branches" &>/dev/null; then

  # Check default branch is same as analysys branch
  if [ "${COMMIT_BRANCH:-none}" == "$DEFAULT_BRANCH" ]; then

    # Create project if not exist
    sq-api projects/create -o /dev/null \
      -d "name=$SONARQUBE_PROJECT_NAME" \
      -d "project=$SONARQUBE_PROJECT_KEY" &&
      info "Project $SONARQUBE_PROJECT_NAME with " \
        "key $SONARQUBE_PROJECT_KEY created in SonarQube"
  else
    sq_must_analyze_in_master=1
  fi
fi

# Let's check if the default branch for the project was previously analyzed.
# If there has not been an analysis yet and the current analysis is
# not started for the default branch, then we issue an error that the
# default branch of the project must first be analyzed.
# Otherwise, problems arise with the first analysis of the project.
if ! jq -er \
  '.branches[] | select(.isMain==true) | .status[]' <<<"$sq_branches" \
  &>/dev/null; then
  if [ "${COMMIT_BRANCH:-none}" != "$DEFAULT_BRANCH" ]; then
    sq_must_analyze_in_master=1
  fi
fi

[ "${sq_must_analyze_in_master:-0}" -eq 1 ] && fail \
  "This is the first analyze of the project $SONARQUBE_PROJECT_NAME" \
  "($SONARQUBE_PROJECT_KEY), and you are trying to do it not from the" \
  "default branch, but from $version. This action is not allowed," \
  "you must first run analyze on the default ($DEFAULT_BRANCH)" \
  'branch, only then will you be able to parse merge requests, tags,' \
  "and other branches. $SUPPORT_CONTACTS"

# TODO migrate to a new method that allows you to change the default
# TODO branch. think through the logic if the default branch is new.

# Get name of current default branch in SQ
sq_curent_default_branch="$(
  jq -er '.branches[] | select(.isMain==true) | .name' <<<"$sq_branches" \
    &>/dev/null || :
)"

# Renaming the default branch SQ to the default branch in GL if they don't
# match. And deleting the non-default duplicate branch.
if [ "${sq_curent_default_branch:-}" != "$DEFAULT_BRANCH" ]; then
  sq_curent_branch="$(
    jq -er ".branches[] | select(.isMain==false) | \
    select(.name==\"""$DEFAULT_BRANCH""\") \
    | .name" <<<"$sq_branches" || :
  )"

  if [ "${sq_curent_branch:-}" == "$DEFAULT_BRANCH" ]; then
    sq-api project_branches/delete \
      -d "branch=$DEFAULT_BRANCH" \
      -d "project=$SONARQUBE_PROJECT_KEY" &&
      warn "SonarQube deleted copy already branch $DEFAULT_BRANCH"
  fi

  sq-api project_branches/rename \
    -d "project=$SONARQUBE_PROJECT_KEY" \
    -d "name=$DEFAULT_BRANCH" &&
    warn "SonarQube default project branch renamed to $DEFAULT_BRANCH"
fi

# Setup ALM integration
sq-api alm_settings/set_gitlab_binding \
  -d "almSetting=$SONARQUBE_ALM_NAME" \
  -d "project=$SONARQUBE_PROJECT_KEY" \
  -d "repository=$PROJECT" &&
  info "SonarQube ALM integration to GitLab updated"
