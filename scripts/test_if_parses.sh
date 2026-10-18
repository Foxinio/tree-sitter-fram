#!/usr/bin/env bash
set -euo pipefail

# Run from the grammar root: scripts/test_if_parses.sh /path/to/dbl/test/ok
if [ "$#" -eq 0 ]; then
  echo "Usage: $0 TEST_DIRECTORY_OR_FILE [...]" >&2
  exit 2
fi

files=()
for path in "$@"; do
  if [ -d "$path" ]; then
    for file in "$path"/*.fram; do
      [ -f "$file" ] && files+=("$file")
    done
  elif [ -f "$path" ]; then
    files+=("$path")
  else
    echo "Not a file or directory: $path" >&2
    exit 2
  fi
done
if [ "${#files[@]}" -eq 0 ]; then
  echo "No .fram files found" >&2
  exit 2
fi

# The CLI's exit status covers both ERROR and missing nodes.
tree-sitter parse --quiet "${files[@]}"
echo "Parsed ${#files[@]} files successfully"
