#!/bin/bash
# find_unused.sh
# Reports Z80 assembly routines (label::) with no callers or data references.
#
# Usage:
#   bash find_unused.sh           # scans ./src
#   bash find_unused.sh path/src  # scans given directory

SRC_DIR="$(cd "$(dirname "$0")" && pwd)/src"
[ -n "$1" ] && SRC_DIR="$1"

unused=0
total=0
unused_labels=()

echo "Scanning: $SRC_DIR"
echo "-------------------------------------------"

while IFS= read -r label; do
    [ -z "$label" ] && continue
    total=$((total + 1))

    def_file=$(grep -rl "^${label}::" "$SRC_DIR" --include="*.s" 2>/dev/null | head -1)

    # Count references: occurrences that are NOT
    #   - the definition line itself  (label::)
    #   - a .globl declaration        (.globl label)
    #   - a pure comment line         (lines starting with optional space + ;)
    ref_count=$(grep -rh -w "$label" "$SRC_DIR" \
            --include="*.s" --include="*.h.s" 2>/dev/null \
        | grep -v "^[[:space:]]*;"         \
        | grep -v "^[[:space:]]*${label}::" \
        | grep -cv "\.globl[[:space:]]")

    if [ "$ref_count" -eq 0 ]; then
        rel="${def_file#$SRC_DIR/}"
        printf "  %-45s %s\n" "$label" "($rel)"
        unused_labels+=("$label")
        unused=$((unused + 1))
    fi

done < <(grep -rh --include="*.s" '^[a-zA-Z_][a-zA-Z0-9_]*::' "$SRC_DIR" 2>/dev/null \
         | sed 's/::.*//' \
         | sort -u)

echo "-------------------------------------------"
echo "Routines scanned : $total"
echo "Unused           : $unused"

if [ "$unused" -gt 0 ]; then
    echo ""
    echo "NOTE: data labels (arrays, strings, templates) also appear here"
    echo "if nothing in the assembly references them by name."
fi
