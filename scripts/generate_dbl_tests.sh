#!/usr/bin/env bash
# ABOUTME: Generates tree-sitter test corpus from dbl test suite files
# ABOUTME: Creates test files with empty expected parse trees for manual completion

set -e

# Create target directory if needed
mkdir -p ./test/corpus/expect_dbl

# Get the dbl test directory
DBL_TEST_DIR="../dbl/test/ok"

if [ ! -d "$DBL_TEST_DIR" ]; then
    echo "Error: DBL test directory not found at $DBL_TEST_DIR"
    exit 1
fi

# Function to extract source from existing test file
extract_source() {
    local test_file="$1"
    awk 'BEGIN{flag=0}
         /^==================$/{flag++; next}
         flag==2 && /^---$/{exit}
         flag==2{print}' "$test_file"
}

# Function to extract expected parse tree from existing test file
extract_expected() {
    local test_file="$1"
    awk '/^---$/{flag=1; next} flag{print}' "$test_file"
}

# Create temp file once for reuse
temp_file=$(mktemp)
trap "rm -f $temp_file" EXIT

# Iterate over .fram files in the test suite
for fram_file in "$DBL_TEST_DIR"/*.fram; do
    # Skip if no .fram files found
    [ -e "$fram_file" ] || continue

    # Get the basename without extension
    basename=$(basename "$fram_file" .fram)
    filename=$(basename "$fram_file")

    # Target test file
    test_file="./test/corpus/expect_dbl/${basename}.txt"

    # Track whether we should preserve expected section
    preserve_expected=""

    # Check if test file already exists
    if [ -f "$test_file" ]; then
        # Extract the source section from existing test file
        extract_source "$test_file" > "$temp_file"

        # Compare by stripping trailing whitespace from both
        if diff_output=$(diff -u <(perl -pe 's/\s+$//' "$temp_file") <(perl -pe 's/\s+$//' "$fram_file") 2>&1); then
            # Same content, skip quietly
            continue
        else
            # Different content, show diff and ask user
            echo ""
            echo "Test file $test_file exists but has different content."
            echo ""
            echo "Diff (old vs new):"
            echo "$diff_output"
            echo ""
            echo -n "Do you want to overwrite it? (y/n) "
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                echo "Skipping $basename"
                continue
            fi
            # User confirmed overwrite - preserve expected section
            preserve_expected=$(extract_expected "$test_file")
        fi
    fi

    # Create the test file
    {
        echo "=================="
        echo "$filename"
        echo "=================="
        cat "$fram_file"
        echo "---"
        if [ -n "$preserve_expected" ]; then
            # Preserve existing expected section
            echo "$preserve_expected"
        else
            # New test file, empty expected section
            echo ""
        fi
    } > "$test_file"

    echo "Created/updated test for $filename"
done

echo ""
echo "Done!"
