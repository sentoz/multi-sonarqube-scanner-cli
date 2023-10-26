#front/go/ruby/all
ARG BASE_IMAGE_NAME="sentoz/multi-sonarqube-scanner-cli"
ARG BASE_IMAGE_TAG="latest-base-jammy"
FROM golang:1.20.1 AS go

FROM $BASE_IMAGE_NAME:$BASE_IMAGE_TAG

LABEL org.opencontainers.image.authors="Dmitriy Okladin <sentoz66@gmail.com>"
LABEL org.opencontainers.image.source="https://github.com/sentoz/multi-sonarqube-scanner-cli"

ARG SONARQUBE_TOKEN
ARG SONARQUBE_URL

ARG SONAR_SCANNER_HOME=/opt/sonar-scanner

ARG PIP_INDEX_URL=https://pypi.org/simple/
ARG PIP_INDEX=https://pypi.org/pypi/

COPY --from=go /usr/local/go/ /usr/local/go/

ENV HOME=/tmp
ENV XDG_CONFIG_HOME=/tmp
ENV SONAR_SCANNER_HOME=$SONAR_SCANNER_HOME
ENV SONAR_USER_HOME=$SONAR_SCANNER_HOME/.sonar
ENV PATH=$SONAR_SCANNER_HOME/bin:$PATH
ENV NODE_PATH=/usr/lib/node_modules
ENV SRC_PATH=/usr/src
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV JAVA_OPTS="-Danalyzer.bundle.audit.path=/usr/bin/bundle-audit -Danalyzer.golang.path=/usr/local/go/bin/go"

WORKDIR /opt

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# hadolint ignore=DL3008,DL3013,DL3016,DL3028,SC2015,SC1001
RUN set -eux; \
    apt-get update && apt-get upgrade -y; \
    apt-get install -yq --no-install-recommends \
        python3 python3-pip ruby ruby-rdoc; \
    wget -qO- https://deb.nodesource.com/setup_16.x | bash - ;\
    apt-get install -y --no-install-recommends nodejs build-essential && \
    node --version && \
    npm --version; \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    gem install bundle-audit; \
    bundle-audit update; \
    npm install -g pnpm; \  
    pip install --no-cache-dir --upgrade pip; \
    pip install --no-cache-dir pylint;

WORKDIR $SRC_PATH

ENTRYPOINT ["/usr/bin/docker_entrypoint"]