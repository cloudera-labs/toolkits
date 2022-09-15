#!/usr/bin/env bash
set -e
DIR=`dirname $0`
exec $DIR/.venv/bin/python $DIR/mac-discovery-bundle-builder/discovery_bundle_builder.py "$@"
