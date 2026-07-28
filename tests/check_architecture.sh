#!/bin/sh

project_root=${1:-..}
src_dir="$project_root/src"
globals_file="$src_dir/globals.inc"
failures=0
test_number=0

report() {
    test_number=$((test_number + 1))
    if "$1"; then
        echo "ok $test_number - $2"
    else
        echo "not ok $test_number - $2"
        failures=$((failures + 1))
    fi
}

framework_has_no_game_imports() {
    ! rg -n '\.include "[^"]*game/' "$src_dir/sys" --glob '*.s' --glob '*.inc'
}

globals_are_centralized() {
    outside=$(rg -l '^\s*\.globl\s+' "$src_dir" --glob '*.s' --glob '*.inc' |
        grep -v "^$globals_file$" || true)
    test -z "$outside"
}

globals_are_unique() {
    duplicates=$(awk '/^\.globl / { count[$2]++ }
        END { for (symbol in count) if (count[symbol] > 1) print symbol }' "$globals_file")
    test -z "$duplicates"
}

global_definitions_are_registered() {
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM
    rg --no-filename -o '^[A-Za-z_.$][A-Za-z0-9_.$]*::' "$src_dir" --glob '*.s' |
        sed 's/::$//' | sort -u > "$temp_dir/definitions"
    awk '/^\.globl / { print $2 }' "$globals_file" | sort -u > "$temp_dir/declarations"
    missing=$(comm -23 "$temp_dir/definitions" "$temp_dir/declarations")
    rm -rf "$temp_dir"
    trap - EXIT HUP INT TERM
    test -z "$missing"
}

echo "TAP version 13"
report framework_has_no_game_imports "framework does not import the game layer"
report globals_are_centralized "global declarations are centralized"
report globals_are_unique "global declarations contain no duplicates"
report global_definitions_are_registered "global definitions are registered"
echo "1..$test_number"

test "$failures" -eq 0

