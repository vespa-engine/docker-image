#!/bin/sh

set -x
set -e
if [ -f /files/share/maven/bin/mvn ]; then
    dnf -y remove maven-lib --noautoremove
    cp -R /files/share /usr
    ln -snf /usr/share/maven/bin/mvn /usr/bin
    ls -l /usr/bin/mvn
    ls -L /usr/bin/mvn
fi
