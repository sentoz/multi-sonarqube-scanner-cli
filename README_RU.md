<!-- omit in toc -->
# Multi SonarQube Scanner

<!-- rule: current lang, other langs sorted by alpha -->
> This document is available in languages: [eng 🇬🇧][], [rus 🇷🇺][]

В данном образе объединены:

* [SonarQube Scanner Cli][]
* [OWASP DependencyCheck][]
* Добавление проекта в SonarQube и синхронизация ветки по умолчанию
* Синхронизация прав SonarQube и Gitlab через [guassp][]
* Запуск тестов для .Net
* Получение покрытия кода из SonarQube

Отдельное спасибо [WoozyMasta][] за утилиту [guassp][].

* [Сборка](#сборка)
  * [Сборка образа с кэшем плагинов](#сборка-образа-с-кэшем-плагинов)
* [Образы](#образы)
  * [Стандартный образ](#стандартный-образ)
  * [Образы для анализа .NET проектов](#образы-для-анализа-net-проектов)
  * [Образ для анализа Gradle проектов](#образ-для-анализа-gradle-проектов)
* [Переменные](#переменные)
  * [Маппинг переменных](#маппинг-переменных)
    * [Github Actions](#github-actions)
    * [Gitlab CI](#gitlab-ci)
  * [SonarQube](#sonarqube)
    * [Общие](#общие)
    * [Github Action](#github-action)
    * [GitLab CI](#gitlab-ci-1)
  * [OWASP Dependency Check](#owasp-dependency-check)
    * [База данных](#база-данных)
    * [Критерии оценки](#критерии-оценки)
    * [OSS Index](#oss-index)
    * [Удаление ложных срабатываний](#удаление-ложных-срабатываний)
  * [Переменные для .Net](#переменные-для-net)
    * [Nuget](#nuget)
    * [.Net](#net)
    * [Tests](#tests)
  * [Исключение стадий](#исключение-стадий)
  * [Прочее](#прочее)

## Сборка

Для сборки необходимо передать аргументы:

* **`SONAR_SCANNER_VERSION`**=`4.8.0.2856` - версия сканера, взять можно в
  репозитории проекта [sonar-scanner-cli][]
* **`DOTNET_SONARSCANNER_VERSION`**=`5.4.1` - версия dotnet-sonarscanner
* **`GRADLE_VERSION`**=`8.1.1` - версия gradle
* **`POSTGRES_DRIVER_VERSION`**=`42.2.19` - версия драйвера postgres
* **`MYSQL_DRIVER_VERSION`**=`8.0.23` - версия драйвера mysql
* **`DEPENDENCY_CHECK_VERSION`**=`8.1.2` - версия [DependencyCheck][]

### Сборка образа с кэшем плагинов

Для ускорения прохождения стадии можно в образ при сборке упаковать все
необходимые плагины и базы SonarQube, для этого во время сборки передайте
переменные:

* **`SONARQUBE_TOKEN`**=`XXTOKENXX` - Токен SonarQube, должен иметь права на
  создание проектов и выполнение анализа
* **`SONARQUBE_URL`**=`https://sonarqube.com` - Адрес SonarQube

А в конец секции `RUN` Dockerfile'a добавьте:

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

В образ будет упакован текущий кеш плагинов в директорию
`/opt/sonar-scanner/.sonar`

## Образы

### Стандартный образ

Данный образ позволяет сканировать проекты реализованные на языках:

* typescript|javascript
* python
* go
* ruby
* shell
* html
* css

### Образы для анализа .NET проектов

`sentoz/multi-sonarqube-scanner-cli:0.1.1-dotnet-3.1`  
`sentoz/multi-sonarqube-scanner-cli:0.1.1-dotnet-5.0`  
`sentoz/multi-sonarqube-scanner-cli:0.1.1-dotnet-6.0`  
`sentoz/multi-sonarqube-scanner-cli:0.1.1-dotnet-7.0`  

Каждый образ собирается на последней стабильной версии `.Net`, включает в себя
`dotnet sonarscanner` и `reportgenerator`.

### Образ для анализа Gradle проектов

`sentoz/multi-sonarqube-scanner-cli:0.1.1-gradle-8.1.1`  
`sentoz/multi-sonarqube-scanner-cli:0.1.1-gradle-7.3.3`  

В образ пакуются бинарные файлы gradle последней стабильной версии.

## Переменные

### Маппинг переменных

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

#### Общие

* **`SONARQUBE_URL`** - Адрес сервера SonarQube
* **`SONARQUBE_TOKEN`** - Токен для подключения к SonarQube
* **`SONARQUBE_CUSTOM_ARGS`** - Список вспомогательных ключей для SonarScaner
  разделенный запятой, к примеру:
  `sonar.exclusions=/path, sonar.test.exclusions=/path2`
* **`SONARQUBE_GENERIC_REPORTS_FILE`**=`$PROJECT_DIR/issues.json` - Файл с
  **generic** репортами
* **`SONARQUBE_QUALITYGATE_WAIT`**=`true` - ожидание получения состояния
  Quality Gate
* **`SONARQUBE_QUALITYGATE_TIMEOUT`**=`300` - таймаут ожидания состояния
  Quality Gate
* **`SONARQUBE_LOG_LEVEL`**=`INFO` - Уровень логирования SonarQube Scanner
* **`SONARQUBE_VERBOSE`**=`true` - больше информации в журнале анализа
* **`SONARQUBE_PYTHON_VERSION`**=`3` - Версия python
* **`SONARQUBE_ALOW_FAILURE`**=`false` - Критичность падения стадии SonarQube
    Scanner.

#### Github Action

* **`SONARQUBE_PROJECT_NAME`**=`$GITHUB_REPOSITORY`
* **`SONARQUBE_PROJECT_KEY`**=`${GITHUB_REPOSITORY#*/}`

#### GitLab CI

* **`SONARQUBE_PROJECT_NAME`**=`$CI_PROJECT_NAMESPACE/$CI_PROJECT_NAME`
* **`SONARQUBE_PROJECT_KEY`**=`gitlab:$CI_PROJECT_ID`

### OWASP Dependency Check

#### База данных

Для ускорения прохождения pipeline, dependency check может хранить базу
уязвимостей в отдельной базе данных и при старте проверки брать данные из нее,
а не выкачивать из интернета при каждом запуске.

* **`OWASP_DEPENDENCY_CHECK_DB_DRIVER`**=`org.postgresql.Driver` - Используемый
  драйвер баз данных(org.postgresql.Driver или com.mysql.jdbc.Driver)
* **`OWASP_DEPENDENCY_CHECK_DB_STRING`** - строка подключения к базе
  данных
* **`OWASP_DEPENDENCY_CHECK_DB_PASSWORD`** - пароль для подключения к базе
  данных
* **`OWASP_DEPENDENCY_CHECK_DB_USER`** - имя пользователя для подключения к
  базе данных
* **`OWASP_DEPENDENCY_CHECK_CVE_VALID_HOURS`** - `24` - Кол-во часов через
  сколько будет выполняться проверка наличия обновления базы из NVD.

#### Критерии оценки

* **`OWASP_DEPENDENCY_CHECK_SEVERITY_BLOCKER`** - `9.0`
* **`OWASP_DEPENDENCY_CHECK_SEVERITY_CRITICAL`** - `7.0`
* **`OWASP_DEPENDENCY_CHECK_SEVERITY_MAJOR`** - `4.0`
* **`OWASP_DEPENDENCY_CHECK_SEVERITY_MINOR`** - `0.0`

#### OSS Index

* **`OWASP_DEPENDENCY_CHECK_DISABLE_OSS_INDEX`** - `true` - Отключение OSS Index
* **`OWASP_DEPENDENCY_CHECK_OSS_INDEX_USERNAME`** - Имя пользователя для
  подключения к Sonatype's OSS Index(опционально)
* **`OWASP_DEPENDENCY_CHECK_OSS_INDEX_PASSWORD`** - Пароль для подключения к
    Sonatype's OSS Index(опционально)

#### Удаление ложных срабатываний

* **`OWASP_DEPENDENCY_CHECK_SUPPRESSIONS_FILE_PATH`** -
  `$PROJECT_DIR/suppression.xml` -
  Используйте suppression файл для удаления [ложных срабатываний][] если они
  есть.

### Переменные для .Net

#### Nuget

Если вы хотите подключать источники при помощи nuget.config, то его необходимо
расположить в том же каталоге, где и *.sln файл согласно
[официальной документации](https://learn.microsoft.com/ru-ru/nuget/consume-packages/configuring-nuget-behavior)

* **`NUGET_PRIVATE_REGISTRY_URL`** - Адрес до приватного реестра
  пакетов(опционально)
* **`NUGET_PRIVATE_REGISTRY_USERNAME`** - Имя пользователя для авторизации в
  приватном реестре пакетов(опционально)
* **`NUGET_PRIVATE_REGISTRY_TOKEN`** - Токен для авторизации в приватном
  реестре пакетов(опционально)
* **`NUGET_REGISTRY_URL`** - Адрес до публичного кэширующего реестра
  пакетов(опционально)

#### .Net

* **`DOTNET_PROJECT_CONFIGURATION`**=`Debug` - Конфигурация сборки
* **`DOTNET_VERBOSITY`**=`minimal` - Уровень логирования
* **`DOTNET_CUSTOM_BUILD_ARGUMENTS`** - Кастомные аргументы сборки приложения
* **`DOTNET_CUSTOM_TEST_ARGUMENTS`** - Кастомные аргументы тестов приложения
* **`DOTNET_WORK_DIR`**=`$PROJECT_DIR` - Каталог с sln файлом
* **`DOTNET_CSPROJ_FILE_PATH`** - Путь до csproj файла приложения
* **`DOTNET_CSPROJ_FILE_TEST_PATH`** - Путь до csproj файла тестов
* **`DOTNET_RESTORE_ATTEMPT_COUNT`** - Кол-во попыток выполнения
  `dotnet restore` в случае падения

#### Tests

* **`SKIP_DOTNET_TEST`**=`false` - Пропуск тестов для .Net

### Исключение стадий

* **`SKIP_DEPENDENCY_CHECK_JOB`**=`false` - Пропустить сканирование
  DependencyCheck
* **`SKIP_SONARQUBE_PREPARE`**=`false` - Пропустить предварительную настройку
  проекта в SonarQube
* **`SKIP_SONARQUBE_SCANNER_JOB`**=`false` - Пропустить сканирование SonarQube
  Scanner
* **`SKIP_SONARQUBE_PERMISSIONS_SYNC`**=`false` - Пропустить синхронизацию прав
* **`SKIP_SONARQUBE_COVERAGE`**=`false` - Пропустить запрос покрытия кода

### Прочее

* **`SUPPORT_CONTACTS`** =
  `https://github.com/sentoz/multi-sonarqube-scanner-cli/issues` - Контакты
  для обратной связи

<!-- Links -->
[eng 🇬🇧]: ./README.md
[rus 🇷🇺]: ./README_RU.md

[SonarQube Scanner Cli]: https://github.com/SonarSource/sonar-scanner-cli
[OWASP DependencyCheck]: https://github.com/jeremylong/DependencyCheck
[sonar-scanner-cli]: https://github.com/SonarSource/sonar-scanner-cli
[DependencyCheck]: https://github.com/jeremylong/DependencyCheck
[ложных срабатываний]: https://jeremylong.github.io/DependencyCheck/general/suppression.html
[guassp]: https://github.com/WoozyMasta/guassp
[WoozyMasta]: https://github.com/WoozyMasta
