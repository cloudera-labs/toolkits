#!/usr/bin/env bash
set -e
DIR=`dirname $0`
exec $DIR/.venv/bin/python $DIR/mac-discovery-reports-builder/discovery_bundle_reports_builder.py "$@"
