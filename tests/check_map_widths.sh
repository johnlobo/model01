#!/bin/sh
set -eu

assembler=$1
project=$2
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

echo "TAP version 13"

if "$assembler" -l -o -s -I"$project/src" \
    "$tmp_dir/map_width_15.rel" "$project/tests/fixtures/map_width_15.s"; then
    echo "ok 1 - generic map-width indexing assembles"
else
    echo "not ok 1 - generic map-width indexing assembles"
    exit 1
fi

if "$assembler" -l -o -s -I"$project/src" \
    "$tmp_dir/map_width_16.rel" "$project/tests/fixtures/map_width_16.s"; then
    echo "ok 2 - optimized map-width indexing assembles"
else
    echo "not ok 2 - optimized map-width indexing assembles"
    exit 1
fi

echo "1..2"
