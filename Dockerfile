# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
FROM centos:7

ARG VESPA_VERSION

ADD include/start-container.sh /usr/local/bin/start-container.sh

RUN yum-config-manager --add-repo https://copr.fedorainfracloud.org/coprs/g/vespa/vespa/repo/epel-7/group_vespa-vespa-epel-7.repo && \
    yum -y install epel-release && \
    yum -y install centos-release-scl && \
    yum -y install --setopt=skip_missing_names_on_install=False \
      bind-utils \
      git \
      net-tools \
      sudo \
      vespa-$VESPA_VERSION && \
    yum clean all

RUN yum -y install --setopt=skip_missing_names_on_install=False gcc-c++ python3-devel && \
    pip3 install --no-cache-dir --upgrade pip && \
    pip3 install --no-cache-dir tensorflow==1.15.3 tf2onnx && \
    yum -y remove gcc-c++ python3-devel && \
    yum clean all

ENTRYPOINT ["/usr/local/bin/start-container.sh"]
