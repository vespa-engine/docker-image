# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

FROM quay.io/centos/centos:stream8

ARG VESPA_VERSION

ADD include/start-container.sh /usr/local/bin/start-container.sh

RUN groupadd -g 1000 vespa && \
    useradd -u 1000 -g vespa -d /opt/vespa -s /sbin/nologin vespa

RUN echo "install_weak_deps=False" >> /etc/dnf/dnf.conf && \
    dnf config-manager --add-repo https://copr.fedorainfracloud.org/coprs/g/vespa/vespa/repo/centos-stream-8/group_vespa-vespa-centos-stream-8.repo && \
    dnf config-manager --enable powertools && \
    dnf -y install epel-release && \
    dnf -y install \
      bind-utils \
      git-core \
      net-tools \
      sudo \
      vespa-$VESPA_VERSION && \
    dnf upgrade -y --nogpgcheck --disablerepo='*' --repofrompath alma-8-latest,https://repo.almalinux.org/almalinux/8/AppStream/$(arch)/os \
      $(rpm -qa --qf '%{NAME}\n' java-* | xargs) && \
    alternatives --set java java-17-openjdk.$(arch) && \
    alternatives --set javac java-17-openjdk.$(arch) && \
    dnf clean all && \
    rm -rf /var/cache/dnf

LABEL org.opencontainers.image.authors="Vespa (https://vespa.ai)" \
      org.opencontainers.image.base.name="quay.io/centos/centos:stream8" \
      org.opencontainers.image.description="Easily serve your big data - generate responses in milliseconds at any scale and with any traffic volume. Read more at the Vespa project https://vespa.ai" \
      org.opencontainers.image.documentation="https://docs.vespa.ai" \
      org.opencontainers.image.licenses="Apache License 2.0" \
      org.opencontainers.image.revision="v$VESPA_VERSION" \
      org.opencontainers.image.source="https://github.com/vespa-engine/docker-image" \
      org.opencontainers.image.title="Vespa - The open big data serving engine" \
      org.opencontainers.image.url="https://hub.docker.com/r/vespaengine/vespa" \
      org.opencontainers.image.vendor="Yahoo" \
      org.opencontainers.image.version="$VESPA_VERSION"

ENTRYPOINT ["/usr/local/bin/start-container.sh"]
