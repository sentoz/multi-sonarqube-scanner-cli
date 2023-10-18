#!/usr/bin/env bash

# Set default env for dotnet restore, build, test
: "${DOTNET_VERBOSITY:=minimal}"
: "${DOTNET_WORK_DIR:="./"}"
: "${DOTNET_CSPROJ_FILE_PATH:=}"
: "${DOTNET_CSPROJ_FILE_TEST_PATH:=}"
: "${DOTNET_NUGET_CONFIG_PATH:=}"
: "${DOTNET_RESTORE_ATTEMPT_COUNT:=3}"
: "${SKIP_DOTNET_TEST:=false}"

# Path normalization
for var in DOTNET_WORK_DIR DOTNET_CSPROJ_FILE_PATH \
  DOTNET_CSPROJ_FILE_TEST_PATH; do
  [ -z "${!var}" ] && continue
  [ "${!var}" == "./" ] && continue
  [ ${!var:0:1} == / ] && fail "Path in variable $var must begining" \
    'with "./"'
  val="./${!var#"./"}"

  printf -v "$var" %s "$val"
done

# Arg if run dotnet test
if ! is-true "$SKIP_DOTNET_TEST"; then
  section-start 'scanner' "Run SonarQube scanner and tests for .Net"
  coverage_report="$PROJECT_DIR/SonarQube.xml"
  sq_args+=("$sq_key.coverageReportPaths=$coverage_report")
else
  section-start 'scanner' "Run SonarQube scanner for .Net"
fi

# Try detect DOTNET_WORK_DIR on the project without the specified csproj file
if [ -z "$DOTNET_CSPROJ_FILE_PATH" ]; then
  mapfile -t sln_list < <(find "$DOTNET_WORK_DIR" -type f -name "*.sln")

  [ "${#sln_list[@]}" -eq 1 ] || fail \
    "${#sln_list[@]} (${sln_list[*]}) *.sln files were found in the project," \
    'set the correct working directory path in the DOTNET_WORK_DIR' \
    'variable or specify the path to a specific *.csproj file in the' \
    "DOTNET_CSPROJ_FILE_PATH variable. $SUPPORT_CONTACTS"

  DOTNET_WORK_DIR="$(dirname "${sln_list[0]}")"
fi
cd "$DOTNET_WORK_DIR" || fail "Workdir not accessible $DOTNET_WORK_DIR"

# Set csproj and set test csproj path
dotnet_csproj_test_file="${DOTNET_CSPROJ_FILE_TEST_PATH#"$DOTNET_WORK_DIR"}"
dotnet_csproj_test_file="${dotnet_csproj_test_file#"/"}"
dotnet_csproj_file="${DOTNET_CSPROJ_FILE_PATH#"$DOTNET_WORK_DIR"}"
dotnet_csproj_file="${dotnet_csproj_file#"/"}"

# Check DOTNET_CSPROJ_FILE_PATH and DOTNET_CSPROJ_FILE_TEST_PATH
if [ -n "$DOTNET_CSPROJ_FILE_TEST_PATH" ]; then
  [ -f "$dotnet_csproj_test_file" ] || fail \
    "*.csproj file does not exist on path $DOTNET_CSPROJ_FILE_PATH " \
    'specified in the DOTNET_CSPROJ_FILE_PATH variable ' \
    ', set the correct working directory path in the DOTNET_WORK_DIR ' \
    'variable or specify the path to a specific *.csproj file in the ' \
    "DOTNET_CSPROJ_FILE_PATH variable. $SUPPORT_CONTACTS"
fi

if [ -n "$DOTNET_CSPROJ_FILE_PATH" ]; then
  [ -f "$dotnet_csproj_file" ] || fail \
    "*.csproj file does not exist on path $DOTNET_CSPROJ_FILE_TEST_PATH " \
    'specified in the DOTNET_CSPROJ_FILE_TEST_PATH variable ' \
    ', set the correct working directory path in the DOTNET_WORK_DIR ' \
    'variable or specify the path to a specific *.csproj file in the ' \
    "DOTNET_CSPROJ_FILE_TEST_PATH variable. $SUPPORT_CONTACTS"
fi

# Connect the private nuget registry to get dependencies
[ -n "${NUGET_PRIVATE_REGISTRY_URL:-}" ] &&
  dotnet nuget add source "$NUGET_PRIVATE_REGISTRY_URL" \
    --name private \
    --username "${NUGET_PRIVATE_REGISTRY_USERNAME:-$GROUP_READ_TOKEN_USERNAME}" \
    --password "${NUGET_PRIVATE_REGISTRY_TOKEN:-$GROUP_REPOSITORY_READ_TOKEN}" \
    --store-password-in-clear-text

# Connect caching proxy nuget registry
[ -n "${NUGET_REGISTRY_URL:-}" ] &&
  dotnet nuget add source "$NUGET_REGISTRY_URL" --name cache

# Restore dependecies
i=0
c="$DOTNET_RESTORE_ATTEMPT_COUNT"
while ! dotnet restore "${dotnet_csproj_file:-}" \
  --verbosity "$DOTNET_VERBOSITY" --no-cache \
  --ignore-failed-sources; do
  ((i++))
  warn "Restore dependencies, attempt $i/$c failed"
  ((i == c)) && fail "Dotnet restore failed"
  sleep 1
done

# Begin scanner task
dotnet sonarscanner begin \
  /k:"$SONARQUBE_PROJECT_KEY" \
  /n:"$SONARQUBE_PROJECT_NAME" \
  "${sq_args[@]}" || __e_sq=1

# Prepare custom build arguments
# shellcheck disable=SC2086
read -r -a net_cust_build_arg <<<${DOTNET_CUSTOM_BUILD_ARGUMENTS:-}
# Build project
# shellcheck disable=SC2086,SC2068
dotnet build ${dotnet_csproj_file:-} \
  --verbosity "$DOTNET_VERBOSITY" \
  -c "${DOTNET_PROJECT_CONFIGURATION:=Debug}" \
  ${net_cust_build_arg[@]:-} || __e_dotnet=1

if ! is-true "$SKIP_DOTNET_TEST"; then
  # Prepare custom test arguments
  # shellcheck disable=SC2086
  read -r -a net_cust_test_arg <<<${DOTNET_CUSTOM_TEST_ARGUMENTS:-}
  # Test project
  junit_log="$PROJECT_DIR/test-result.xml"
  junit="LogFilePath=$junit_log;MethodFormat=Class;FailureBodyFormat=Verbose"
  # shellcheck disable=SC2086,SC2068
  dotnet test ${dotnet_csproj_test_file:-} \
    --verbosity "$DOTNET_VERBOSITY" \
    --test-adapter-path:. \
    "--logger:junit;$junit" \
    /p:CollectCoverage=true \
    /p:CoverletOutputFormat=Cobertura \
    /p:CoverletOutput="$PROJECT_DIR/" \
    ${net_cust_test_arg[@]:-} || __e_test=1

  # Check report result test coverage.cobertura.xml
  [ -s "$PROJECT_DIR/coverage.cobertura.xml" ] || fail \
    "Test results report was not found. The tests were run with the" \
    "dotnet test ${dotnet_csproj_test_file:-} --test-adapter-path:." \
    "--logger:junit;$junit /p:CollectCoverage=true" \
    "/p:CoverletOutputFormat=Cobertura /p:CoverletOutput=$PROJECT_DIR/" \
    'Check tests and dependencies "JunitXml.TestLogger", "coverlet.msbuild"' \
    "in the project."

  # Create reports
  reportgenerator "-reports:$PROJECT_DIR/coverage.cobertura.xml" \
    -targetdir:"$PROJECT_DIR"/ '-reportTypes:SonarQube;TextSummary' || __e_sq=1
fi

# Finalize scanner task
dotnet sonarscanner end /d:sonar.login="$SONARQUBE_TOKEN" || __e_sq=1

section-end
