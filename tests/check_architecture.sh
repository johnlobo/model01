#!/bin/sh

project_root=${1:-..}
src_dir="$project_root/src"
globals_file="$src_dir/globals.inc"
config_file="$src_dir/config.h.s"
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

config_value() {
    awk -F= -v name="$1" '
        $1 ~ "^[[:space:]]*" name "[[:space:]]*$" {
            value=$2
            sub(/;.*/, "", value)
            gsub(/[[:space:]]/, "", value)
            print value
        }' "$config_file"
}

map_width_fits_cpc_screen() {
    value=$(config_value MAP_WIDTH)
    test "$value" -ge 1 2>/dev/null && test "$value" -le 20
}

map_height_fits_cpc_screen() {
    value=$(config_value MAP_HEIGHT)
    test "$value" -ge 1 2>/dev/null && test "$value" -le 25
}

gravity_fits_signed_velocity() {
    value=$(config_value PHYSICS_GRAVITY)
    test "$value" -ge 0 2>/dev/null && test "$value" -le 127
}

fall_speed_fits_signed_velocity() {
    value=$(config_value PHYSICS_MAX_FALL_SPEED)
    test "$value" -ge 1 2>/dev/null && test "$value" -le 127
}

echo "TAP version 13"
report framework_has_no_game_imports "framework does not import the game layer"
report globals_are_centralized "global declarations are centralized"
report globals_are_unique "global declarations contain no duplicates"
report global_definitions_are_registered "global definitions are registered"
report map_width_fits_cpc_screen "map width fits the 80-byte CPC screen"
report map_height_fits_cpc_screen "map height fits the 200-pixel CPC screen"
report gravity_fits_signed_velocity "gravity fits signed 8-bit velocity"
report fall_speed_fits_signed_velocity "fall speed fits signed 8-bit velocity"
echo "1..$test_number"

test "$failures" -eq 0
