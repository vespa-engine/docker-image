#!/bin/bash
# Copyright 2017 Yahoo Holdings. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

set -e

if [ $# -gt 1 ]; then
    echo "Allowed arguments to entrypoint are {configserver,services}."
    exit 1
fi

# Always set the hostname to the FQDN name if available
hostname $(hostname -f) || true

# Always make sure vespa:vespa owns what is in /opt/vespa
chown -R vespa:vespa /opt/vespa

trap cleanup TERM INT

cleanup() {
    /opt/vespa/bin/vespa-stop-services
    exit $?
}

if [ -n "$1" ]; then
    if [ -z "$VESPA_CONFIGSERVERS" ]; then
        echo "VESPA_CONFIGSERVERS must be set with '-e VESPA_CONFIGSERVERS=<comma separated list of config servers>' argument to docker."
        exit 1
    fi
    case $1 in
        configserver)
            cleanup() {
                /opt/vespa/bin/vespa-stop-configserver
                exit $?
            }
            /opt/vespa/bin/vespa-start-configserver
            ;;
        services)
            /opt/vespa/bin/vespa-start-services
            ;;
        *)
            echo "Allowed arguments to entrypoint are {configserver,services}."
            exit 1
            ;;
    esac
else
    if [ -z "$VESPA_CONFIGSERVERS" ]; then
        export VESPA_CONFIGSERVERS=$(hostname)
    fi
    /opt/vespa/bin/vespa-start-configserver
    /opt/vespa/bin/vespa-start-services
fi

sleep infinity &
wait
