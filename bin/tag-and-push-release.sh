#!/bin/bash
set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <tag>"
    exit 1
fi

readonly VERSION=$1

sed -i.orig "s/^RUN.*yum.*install.*vespa-[0-9]\.[0-9]*\.[0-9]*.*/RUN yum install -y vespa-$VERSION/" Dockerfile
git commit -am "Updated version to $VERSION"
git tag -a -m "Release $VERSION" $VERSION
git push --follow-tags
