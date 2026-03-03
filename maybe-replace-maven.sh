#!/bin/sh

set -x
set -e
if [ -f /files/share/maven/bin/mvn ]; then
    if rpm -q maven-lib >/dev/null 2>&1; then
        dnf -y remove maven-lib --noautoremove
    fi
    cp -R /files/share /usr
    ln -snf /usr/share/maven/bin/mvn /usr/bin
    ls -l /usr/bin/mvn
    ls -L /usr/bin/mvn
fi
