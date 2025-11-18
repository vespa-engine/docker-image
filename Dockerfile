# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

ARG VESPA_BASE_IMAGE=el8

FROM docker.io/almalinux:8 as el8

RUN echo "install_weak_deps=False" >> /etc/dnf/dnf.conf && \
    echo "fastestmirror=0"         >> /etc/dnf/dnf.conf && \
    dnf -y install \
      dnf-plugins-core \
      epel-release && \
    dnf config-manager --add-repo https://copr.fedorainfracloud.org/coprs/g/vespa/vespa/repo/epel-8/group_vespa-vespa-epel-8.repo && \
    /usr/bin/crb enable && \
    dnf remove -y dnf-plugins-core && \
    dnf clean all && \
    rm -rf /var/cache/dnf

LABEL org.opencontainers.image.base.name="docker.io/almalinux:8"

FROM docker.io/almalinux:9 as el9

RUN echo "install_weak_deps=False" >> /etc/dnf/dnf.conf && \
    echo "fastestmirror=0"         >> /etc/dnf/dnf.conf && \
    dnf -y install \
      dnf-plugins-core \
      epel-release && \
    dnf config-manager --add-repo https://copr.fedorainfracloud.org/coprs/g/vespa/vespa/repo/epel-9/group_vespa-vespa-epel-9.repo && \
    /usr/bin/crb enable && \
    dnf remove -y dnf-plugins-core && \
    dnf clean all && \
    rm -rf /var/cache/dnf

LABEL org.opencontainers.image.base.name="docker.io/almalinux:9"

FROM $VESPA_BASE_IMAGE AS vespa

ARG VESPA_VERSION
ARG SOURCE_GITREF=v$VESPA_VERSION

ADD include/start-container.sh /usr/local/bin/start-container.sh

RUN groupadd -g 1000 vespa && \
    useradd -u 1000 -g vespa -d /opt/vespa -s /sbin/nologin vespa

RUN  --mount=type=bind,target=/files,source=.,ro \
    if [[ -d /files/rpms ]]; then echo -e "[vespa-rpms-local]\nname=Local Vespa RPMs\nbaseurl=file:///files/rpms/\nenabled=1\ngpgcheck=0" > /etc/yum.repos.d/vespa-rpms-local.repo; fi && \
    dnf -y install vespa-$VESPA_VERSION && \
    dnf clean all && \
    rm -f /etc/yum.repos.d/vespa-rpms-local.repo && \
    rm -rf /var/cache/dnf

LABEL org.opencontainers.image.authors="Vespa (https://vespa.ai)" \
      org.opencontainers.image.description="Easily serve your big data - generate responses in milliseconds at any scale and with any traffic volume. Read more at the Vespa project https://vespa.ai" \
      org.opencontainers.image.documentation="https://docs.vespa.ai" \
      org.opencontainers.image.licenses="Apache License 2.0" \
      org.opencontainers.image.revision="$SOURCE_GITREF" \
      org.opencontainers.image.source="https://github.com/vespa-engine/docker-image" \
      org.opencontainers.image.title="Vespa - The open big data serving engine" \
      org.opencontainers.image.url="https://hub.docker.com/r/vespaengine/vespa" \
      org.opencontainers.image.vendor="Vespa.ai" \
      org.opencontainers.image.version="$VESPA_VERSION"

ENV PATH="/opt/vespa/bin:/opt/vespa-deps/bin:${PATH}"
ENV VESPA_LOG_STDOUT="true"
ENV VESPA_LOG_FORMAT="vespa"
ENV VESPA_CLI_HOME=/tmp/.vespa
ENV VESPA_CLI_CACHE_DIR=/tmp/.cache/vespa

USER vespa

ENTRYPOINT ["/usr/local/bin/start-container.sh"]
