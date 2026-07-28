#!/bin/sh

log_file=${1:-../obj/model01.bin.log}
highest_hex=$(awk '/Highest address/ { print $4 }' "$log_file")

echo "TAP version 13"

if test -z "$highest_hex"; then
    echo "not ok 1 - binary memory ceiling (highest address missing)"
    echo "1..1"
    exit 1
fi

highest_decimal=$(printf '%d' "0x$highest_hex")
bank_ceiling=$((0x7FFF))

if test "$highest_decimal" -le "$bank_ceiling"; then
    echo "ok 1 - binary ends at 0x$highest_hex within banking window"
    status=0
else
    echo "not ok 1 - binary ends at 0x$highest_hex beyond 0x7FFF"
    status=1
fi

echo "1..1"
exit "$status"

