#!/bin/bash
# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <tag>"
    exit 1
fi

readonly VERSION=$1

git tag -a -m "Release $VERSION" $VERSION
git push --follow-tags
