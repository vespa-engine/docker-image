# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

FROM quay.io/centos/centos:stream8

ARG VESPA_VERSION

ADD include/start-container.sh /usr/local/bin/start-container.sh

RUN echo "install_weak_deps=False" >> /etc/dnf/dnf.conf && \
    dnf config-manager --add-repo https://copr.fedorainfracloud.org/coprs/g/vespa/vespa/repo/centos-stream-8/group_vespa-vespa-centos-stream-8.repo && \
    dnf config-manager --enable powertools && \
    dnf -y install epel-release && \
    dnf -y install \
      bind-utils \
      git \
      net-tools \
      sudo \
      vespa-$VESPA_VERSION && \
    dnf clean all && \
    rm -rf /var/cache/dnf

ENTRYPOINT ["/usr/local/bin/start-container.sh"]
