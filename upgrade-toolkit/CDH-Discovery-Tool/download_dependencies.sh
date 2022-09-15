#!/usr/bin/env bash
set -e
DIR=`dirname $0`
WHEELHOUSE_DIR="$DIR/wheelhouse"
mkdir -p $WHEELHOUSE_DIR && $DIR/.venv/bin/python -m pip download -r "$DIR/requirements.txt" -d $WHEELHOUSE_DIR
cp "$DIR/requirements.txt" $WHEELHOUSE_DIR
tar -zcf "$DIR/wheelhouse.tar.gz" $WHEELHOUSE_DIR
rm -rf $WHEELHOUSE_DIR