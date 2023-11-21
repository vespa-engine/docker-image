# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

ARG VESPA_BASE_IMAGE=el8

FROM docker.io/almalinux:8 as el8

RUN echo "install_weak_deps=False" >> /etc/dnf/dnf.conf && \
    dnf -y install \
      dnf-plugins-core \
      epel-release && \
    dnf config-manager --add-repo https://copr.fedorainfracloud.org/coprs/g/vespa/vespa/repo/epel-8/group_vespa-vespa-epel-8.repo && \
    dnf config-manager --enable powertools && \
    dnf remove -y dnf-plugins-core && \
    dnf clean all && \
    rm -rf /var/cache/dnf

LABEL org.opencontainers.image.base.name="quay.io/centos/centos:stream8"

FROM quay.io/centos/centos:stream8 as stream8

RUN echo "install_weak_deps=False" >> /etc/dnf/dnf.conf && \
    dnf -y install \
      dnf-plugins-core \
      epel-release && \
    dnf config-manager --add-repo https://copr.fedorainfracloud.org/coprs/g/vespa/vespa/repo/epel-8/group_vespa-vespa-epel-8.repo && \
    dnf config-manager --enable powertools && \
    dnf remove -y dnf-plugins-core && \
    dnf clean all && \
    rm -rf /var/cache/dnf

LABEL org.opencontainers.image.base.name="quay.io/centos/centos:stream8"

FROM docker.io/almalinux:9 as el9

RUN echo "install_weak_deps=False" >> /etc/dnf/dnf.conf && \
    dnf -y install \
      dnf-plugins-core \
      epel-release && \
    dnf config-manager --add-repo https://copr.fedorainfracloud.org/coprs/g/vespa/vespa/repo/epel-9/group_vespa-vespa-epel-9.repo && \
    dnf config-manager --enable crb && \
    dnf remove -y dnf-plugins-core && \
    dnf clean all && \
    rm -rf /var/cache/dnf

LABEL org.opencontainers.image.base.name="docker.io/almalinux:9"

FROM $VESPA_BASE_IMAGE AS vespa

ARG VESPA_VERSION

ADD include/start-container.sh /usr/local/bin/start-container.sh

RUN groupadd -g 1000 vespa && \
    useradd -u 1000 -g vespa -d /opt/vespa -s /sbin/nologin vespa

RUN dnf -y install vespa-$VESPA_VERSION && \
    dnf clean all && \
    rm -rf /var/cache/dnf

LABEL org.opencontainers.image.authors="Vespa (https://vespa.ai)" \
      org.opencontainers.image.description="Easily serve your big data - generate responses in milliseconds at any scale and with any traffic volume. Read more at the Vespa project https://vespa.ai" \
      org.opencontainers.image.documentation="https://docs.vespa.ai" \
      org.opencontainers.image.licenses="Apache License 2.0" \
      org.opencontainers.image.revision="v$VESPA_VERSION" \
      org.opencontainers.image.source="https://github.com/vespa-engine/docker-image" \
      org.opencontainers.image.title="Vespa - The open big data serving engine" \
      org.opencontainers.image.url="https://hub.docker.com/r/vespaengine/vespa" \
      org.opencontainers.image.vendor="Yahoo" \
      org.opencontainers.image.version="$VESPA_VERSION"

ENV PATH="/opt/vespa/bin:/opt/vespa-deps/bin:${PATH}"
ENV VESPA_LOG_STDOUT="true"
ENV VESPA_LOG_FORMAT="vespa"
ENV VESPA_CLI_HOME=/tmp/.vespa
ENV VESPA_CLI_CACHE_DIR=/tmp/.cache/vespa

USER vespa

ENTRYPOINT ["/usr/local/bin/start-container.sh"]
