#!/usr/bin/env bash
# ABOUTME: Parses dbl test suite files and saves successful parses with their parse trees
# ABOUTME: Usage: ./save_parse_trees.sh [path_to_test_files] [output_directory]

TEST_PATH="${1:-../scratch-dbl/test/ok}"
OUTPUT_DIR="${2:-./parsed_tests}"

# tree-sitter generate

mkdir -p "$OUTPUT_DIR"

echo "Parsing files from: $TEST_PATH"
echo "Output directory: $OUTPUT_DIR"
echo ""

parsed_count=0
failed_count=0

for f in "$TEST_PATH"/*; do
  if [ ! -f "$f" ]; then
    continue
  fi

  basename=$(basename "$f")
  name="${basename%.*}"

  parse_output=$(tree-sitter parse "$f" 2>&1 || true)

  if echo "$parse_output" | grep -q "ERROR"; then
    echo "FAIL: $basename"
    ((failed_count++))
  else
    echo "OK: $basename"
    cp "$f" "$OUTPUT_DIR/${name}.fram"
    echo "$parse_output" > "$OUTPUT_DIR/${name}.parsed"
    ((parsed_count++))
  fi
done

echo ""
echo "Parsed: $parsed_count"
echo "Failed: $failed_count"
