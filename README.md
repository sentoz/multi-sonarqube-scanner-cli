<!-- omit in toc -->
# Multi SonarQube Scanner

<!-- markdownlint-disable MD033 -->
![Gitleaks][gitleaks-img]
![Hadolint][hadolint-img]

[![GPL-3 licensed][license-img]][license]
[![Docker Image CI][docker-image-ci-img]][docker-image-ci]
[![GitHub release][release-img]][release]

<!-- markdownlint-enable MD033 -->

<!-- rule: current lang, other langs sorted by alpha -->
> This document is available in languages: [eng 🇬🇧][], [rus 🇷🇺][]

In this image are combined:

* [SonarQube Scanner Cli][]
* [OWASP DependencyCheck][]
* Adding a project to SonarQube and syncing the default branch
* Syncing SonarQube and Gitlab entitlements via [guassp][]
* Running tests for .Net
* Code coverage request from SonarQube

Special thanks to [WoozyMasta][] for the utility [guassp][].

* [Build](#build)
  * [Building an Image with a Plugin Cache](#building-an-image-with-a-plugin-cache)
* [Images](#images)
  * [Standard Image](#standard-image)
  * [Images for analyzing .NET projects](#images-for-analyzing-net-projects)
  * [Image for analyzing Gradle projects](#image-for-analyzing-gradle-projects)
* [Variables](#variables)
  * [Variable Mapping](#variable-mapping)
    * [Github Actions](#github-actions)
    * [Gitlab CI](#gitlab-ci)
  * [SonarQube](#sonarqube)
    * [General](#general)
    * [Github Action](#github-action)
    * [GitLab CI](#gitlab-ci-1)
  * [OWASP Dependency Check](#owasp-dependency-check)
    * [Database](#database)
    * [Criteria for evaluation](#criteria-for-evaluation)
    * [OSS Index](#oss-index)
    * [Removing false positives](#removing-false-positives)
  * [Variables for .Net](#variables-for-net)
    * [Nuget](#nuget)
    * [.Net](#net)
    * [Tests](#tests)
  * [Exclusion of stages](#exclusion-of-stages)
  * [Other](#other)

## Build

You need to pass arguments to build.:

* **`SONAR_SCANNER_VERSION`**=`4.8.0.2856` - version of the scanner, you can
  take in project repositories [sonar-scanner-cli][]
* **`DOTNET_SONARSCANNER_VERSION`**=`5.11` - dotnet-sonarscanner version
* **`GRADLE_VERSION`**=`8.1.1` - gradle version
* **`POSTGRES_DRIVER_VERSION`**=`42.2.19` - postgres driver version
* **`MYSQL_DRIVER_VERSION`**=`8.0.23` - mysql driver version
* **`DEPENDENCY_CHECK_VERSION`**=`8.1.2` - [DependencyCheck][] version

### Building an Image with a Plugin Cache

To speed up the passage of the stage, you can pack all the necessary plugins
and SonarQube bases into the image during assembly, to do this, pass the
variables during the assembly:

* **`SONARQUBE_TOKEN`**=`XXTOKENXX` - SonarQube token, must have rights to
  create projects and perform analysis
* **`SONARQUBE_URL`**=`https://sonarqube.com` - SonarQube URL

And at the end of the `RUN` section of the Dockerfile, add:

```bash
    mkdir -p "$SRC_PATH" "$SONAR_USER_HOME" "$SONAR_USER_HOME/cache"; \
    sonar-scanner \
      -Dsonar.qualitygate.wait=false \
      -Dsonar.projectKey=self-build \
      -Dsonar.host.url="$SONARQUBE_URL" \
      -Dsonar.login="$SONARQUBE_TOKEN" \
      -Dsonar.dryRun=true \
      -Dsonar.exclusions='**/dependency-check/bin/*'
```

The current cache of plugins will be packed into the image in the directory
`/opt/sonar-scanner/.sonar`

## Images

### Standard Image

`sentoz/multi-sonar-scanner:0.1.0`

This image allows you to scan projects implemented in languages:

* typescript|javascript
* python
* go
* ruby
* shell
* html
* css

### Images for analyzing .NET projects

`sentoz/multi-sonarqube-scanner-cli:0.1.1-dotnet-3.1`  
`sentoz/multi-sonarqube-scanner-cli:0.1.1-dotnet-5.0`  
`sentoz/multi-sonarqube-scanner-cli:0.1.1-dotnet-6.0`  
`sentoz/multi-sonarqube-scanner-cli:0.1.1-dotnet-7.0`  

Each image is built on the latest stable version of `.Net`, includes
`dotnet sonarscanner` and `reportgenerator`.

### Image for analyzing Gradle projects

`sentoz/multi-sonarqube-scanner-cli:0.1.1-gradle-8.1.1`  
`sentoz/multi-sonarqube-scanner-cli:0.1.1-gradle-7.3.3`  

The gradle binaries of the latest stable version are packed into the image.

## Variables

### Variable Mapping

#### Github Actions

* **`DEFAULT_BRANCH`**=`$GITHUB_BASE_REF`
* **`COMMIT_BRANCH`**=`$GITHUB_REF_NAME`
* **`COMMIT_TAG`**=`${GITHUB_REF#"refs/tags/"}`
* **`JOB_TOKEN`**=`$GITHUB_TOKEN`
* **`PROJECT_DIR`**=`$GITHUB_WORKSPACE`
* **`REF_NAME`**=`$GITHUB_REF_NAME`
* **`MERGE_REQUEST_ID`**=`$GITHUB_RUN_ID`
* **`COMMIT_REF_SLUG`**=`$GITHUB_REF_NAME`
* **`PROJECT_NAME`**=`${GITHUB_REPOSITORY#*/}`
* **`PROJECT_URL`**=`$GITHUB_SERVER_URL/$GITHUB_REPOSITORY`

#### Gitlab CI

* **`DEFAULT_BRANCH`**=`$CI_DEFAULT_BRANCH`
* **`COMMIT_BRANCH`**=`$CI_COMMIT_BRANCH`
* **`COMMIT_TAG`**=`$CI_COMMIT_TAG`
* **`PROJECT`**=`$CI_PROJECT_ID`
* **`JOB_TOKEN`**=`$CI_JOB_TOKEN`
* **`PROJECT_DIR`**=`$CI_PROJECT_DIR`
* **`REF_NAME`**=`$CI_COMMIT_REF_NAME`
* **`MERGE_REQUEST_ID`**=`$CI_MERGE_REQUEST_IID`
* **`PROJECT_NAME`**=`$CI_PROJECT_NAME`
* **`COMMIT_REF_SLUG`**=`$CI_COMMIT_REF_SLUG`
* **`SONARQUBE_ALM_NAME`**=`GitLab`
* **`JOB_TOKEN`**=`$CI_JOB_TOKEN`
* **`PROJECT_URL`**=`$CI_PROJECT_URL`

### SonarQube

#### General

* **`SONARQUBE_URL`** - SonarQube server address
* **`SONARQUBE_TOKEN`** - Token for connecting to SonarQube
* **`SONARQUBE_CUSTOM_ARGS`** - A list of custom keys for SonarScaner separated
  by a comma, for example:
  `sonar.exclusions=/path, sonar.test.exclusions=/path2`
* **`SONARQUBE_GENERIC_REPORTS_FILE`**=`$PROJECT_DIR/issues.json` - File with
  [generic][] reports
* **`SONARQUBE_QUALITYGATE_WAIT`**=`true` - waiting to receive the Quality Gate
  status
* **`SONARQUBE_QUALITYGATE_TIMEOUT`**=`300` - Quality Gate timeout
* **`SONARQUBE_LOG_LEVEL`**=`INFO` - Logging Level SonarQube Scanner
* **`SONARQUBE_VERBOSE`**=`true` - more information in the analysis log
* **`SONARQUBE_PYTHON_VERSION`**=`3` - python version
* **`SONARQUBE_ALOW_FAILURE`**=`false` - Criticality of falling stage SonarQube
  Scanner.

#### Github Action

* **`SONARQUBE_PROJECT_NAME`**=`$GITHUB_REPOSITORY`
* **`SONARQUBE_PROJECT_KEY`**=`${GITHUB_REPOSITORY#*/}`

#### GitLab CI

* **`SONARQUBE_PROJECT_NAME`**=`$CI_PROJECT_NAMESPACE/$CI_PROJECT_NAME`
* **`SONARQUBE_PROJECT_KEY`**=`gitlab:$CI_PROJECT_ID`

### OWASP Dependency Check

#### Database

To speed up the passage of the pipeline, dependency check can store the database
of vulnerabilities in a separate database and, at the start of the check, take
data from it, and not download it from the Internet at each start.

* **`OWASP_DEPENDENCY_CHECK_DB_DRIVER`**=`org.postgresql.Driver` - Database
  driver used(org.postgresql.Driver or com.mysql.jdbc.Driver)
* **`OWASP_DEPENDENCY_CHECK_DB_STRING`** - database connection string
* **`OWASP_DEPENDENCY_CHECK_DB_PASSWORD`** - database connection password
* **`OWASP_DEPENDENCY_CHECK_DB_USER`** - username to connect to the database
* **`OWASP_DEPENDENCY_CHECK_NVD_VALID_HOURS`** - `24` - The number of hours
  after which the NVD will check for a database update.

#### Criteria for evaluation

* **`OWASP_DEPENDENCY_CHECK_SEVERITY_BLOCKER`** - `9.0`
* **`OWASP_DEPENDENCY_CHECK_SEVERITY_CRITICAL`** - `7.0`
* **`OWASP_DEPENDENCY_CHECK_SEVERITY_MAJOR`** - `4.0`
* **`OWASP_DEPENDENCY_CHECK_SEVERITY_MINOR`** - `0.0`

#### OSS Index

* **`OWASP_DEPENDENCY_CHECK_DISABLE_OSS_INDEX`** - `true` - Disabling OSS Index
* **`OWASP_DEPENDENCY_CHECK_OSS_INDEX_USERNAME`** - Username to connect to
  Sonatype's OSS Index (optional)
* **`OWASP_DEPENDENCY_CHECK_OSS_INDEX_PASSWORD`** - Password to connect to
  Sonatype OSS Index(optional)

#### Removing false positives

* **`OWASP_DEPENDENCY_CHECK_SUPPRESSIONS_FILE_PATH`** -
  `$PROJECT_DIR/suppression.xml` -
  Use suppression file to remove [false positives][] if any.

### Variables for .Net

#### Nuget

If you want to connect sources using nuget.config, then it must be placed in
the same directory as the *.sln file according to the
[official documentation](https://learn.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior)

* **`NUGET_PRIVATE_REGISTRY_URL`** - Address to private package
  registry (optional)
* **`NUGET_PRIVATE_REGISTRY_USERNAME`** - Username for authorization in the
  private package registry (optional)
* **`NUGET_PRIVATE_REGISTRY_TOKEN`** - Token for authorization in the private
  package registry (optional)
* **`NUGET_REGISTRY_URL`** - Address to the public caching package
  registry (optional)

#### .Net

* **`DOTNET_PROJECT_CONFIGURATION`**=`Debug` - Build Configuration
* **`DOTNET_VERBOSITY`**=`minimal` - Logging level
* **`DOTNET_CUSTOM_BUILD_ARGUMENTS`** - Custom Application Build Arguments
* **`DOTNET_CUSTOM_TEST_ARGUMENTS`** - Custom Application Test Arguments
* **`DOTNET_WORK_DIR`**=`$PROJECT_DIR` - Directory with sln file (optional)
* **`DOTNET_CSPROJ_FILE_PATH`** - Path to csproj application file (optional)
* **`DOTNET_CSPROJ_FILE_TEST_PATH`** - Path to csproj test file (optional)
* **`DOTNET_RESTORE_ATTEMPT_COUNT`** - Number of execution attempts
  `dotnet restore` in case of a fall

#### Tests

* **`SKIP_DOTNET_TEST`**=`false` - Skipping tests for .Net

### Exclusion of stages

* **`SKIP_DEPENDENCY_CHECK_JOB`**=`false` - Skip DependencyCheck Scan
* **`SKIP_SONARQUBE_PREPARE`**=`false` - Skip project preconfiguration in
  SonarQube
* **`SKIP_SONARQUBE_SCANNER_JOB`**=`false` - Skip SonarQube Scanner
* **`SKIP_SONARQUBE_PERMISSIONS_SYNC`**=`false` - Skip rights sync
* **`SKIP_SONARQUBE_COVERAGE`**=`false` - Skip code coverage request

### Other

* **`SUPPORT_CONTACTS`** =
  `https://github.com/sentoz/multi-sonarqube-scanner-cli/issues` - Contacts for
  feedback

<!-- Links -->
[eng 🇬🇧]: ./README.md
[rus 🇷🇺]: ./README_RU.md

[SonarQube Scanner Cli]: https://github.com/SonarSource/sonar-scanner-cli
[OWASP DependencyCheck]: https://github.com/jeremylong/DependencyCheck
[sonar-scanner-cli]: https://github.com/SonarSource/sonar-scanner-cli
[DependencyCheck]: https://github.com/jeremylong/DependencyCheck
[false positives]: https://jeremylong.github.io/DependencyCheck/general/suppression.html
[guassp]: https://github.com/WoozyMasta/guassp
[WoozyMasta]: https://github.com/WoozyMasta
[generic]: https://docs.sonarqube.org/latest/analyzing-source-code/importing-external-issues/generic-issue-import-format/
[hadolint-img]: https://img.shields.io/badge/hadolint-passing-brightgreen
[gitleaks-img]: https://img.shields.io/badge/protected%20by-gitleaks-blue
[license]: https://tldrlegal.com/l/gpl-3.0
[license-img]: https://img.shields.io/badge/license-GPL--3-blue.svg
[release-img]: https://img.shields.io/github/v/release/sentoz/multi-sonarqube-scanner-cli.svg
[release]: https://github.com/sentoz/multi-sonarqube-scanner-cli/latest
[docker-image-ci]: https://github.com/sentoz/multi-sonarqube-scanner-cli/actions/workflows/docker-images.yml
[docker-image-ci-img]:
    https://github.com/sentoz/multi-sonarqube-scanner-cli/actions/workflows/docker-images.yml/badge.svg?branch=main
