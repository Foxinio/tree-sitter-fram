#!/usr/bin/env bash
# ABOUTME: Interactive script to review and update failing tree-sitter tests
# ABOUTME: in the expect_dbl directory one by one

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

EXPECT_DBL_DIR="test/corpus/expect_dbl"

echo -e "${BLUE}Scanning for failing tests in ${EXPECT_DBL_DIR}...${NC}"
echo

# Get all test files
TEST_FILES=$(find "$EXPECT_DBL_DIR" -name "*.txt" -type f | sort)
TOTAL_FILES=$(echo "$TEST_FILES" | wc -l)

echo -e "${BLUE}Found ${TOTAL_FILES} test file(s)${NC}"
echo

# Find failing tests
FAILING_FILES=()
for test_file in $TEST_FILES; do
    filename=$(basename "$test_file")
    # Run test and check if it fails (exit code != 0 means failure)
    if ! tree-sitter test --file-name "$filename" >/dev/null 2>&1; then
        FAILING_FILES+=("$filename")
    fi
done

TOTAL_FAILURES=${#FAILING_FILES[@]}

if [ "$TOTAL_FAILURES" -eq 0 ]; then
    echo -e "${GREEN}No failing tests found in ${EXPECT_DBL_DIR}!${NC}"
    exit 0
fi

echo -e "${YELLOW}Found ${TOTAL_FAILURES} failing test file(s)${NC}"
echo

CURRENT=0
UPDATED=0
SKIPPED=0

# Process each failing test file
for filename in "${FAILING_FILES[@]}"; do
    CURRENT=$((CURRENT + 1))

    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Test file ${CURRENT}/${TOTAL_FAILURES}: ${filename}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo

    # Extract and show source code from the test file
    test_filepath="$EXPECT_DBL_DIR/$filename"
    echo -e "${BLUE}Source code:${NC}"
    # Extract lines between the header (3 lines) and the --- separator
    awk 'NR>3 && /^---$/ {exit} NR>3 {print}' "$test_filepath"
    echo

    # Show the test diff
    echo -e "${YELLOW}Running test to show diff:${NC}"
    tree-sitter test --file-name "$filename" 2>&1 || true
    echo

    # Prompt user
    while true; do
        echo -ne "${YELLOW}Update this test? [y/n/q]: ${NC}"
        read -r response

        case "$response" in
            [Yy]*)
                echo -e "${GREEN}Updating test...${NC}"
                tree-sitter test --update --file-name "$filename"
                UPDATED=$((UPDATED + 1))
                echo -e "${GREEN}✓ Test updated${NC}"
                echo
                break
                ;;
            [Nn]*)
                echo -e "${YELLOW}Skipping test${NC}"
                SKIPPED=$((SKIPPED + 1))
                echo
                break
                ;;
            [Qq]*)
                echo
                echo -e "${BLUE}Summary:${NC}"
                echo -e "  Updated: ${GREEN}${UPDATED}${NC}"
                echo -e "  Skipped: ${YELLOW}${SKIPPED}${NC}"
                echo -e "  Remaining: $((TOTAL_FAILURES - CURRENT))"
                echo
                echo -e "${YELLOW}Exiting...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid response. Please enter y (yes), n (no), or q (quit)${NC}"
                ;;
        esac
    done
done

# Final summary
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}All tests processed!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo
echo -e "${BLUE}Summary:${NC}"
echo -e "  Total failing tests: ${TOTAL_FAILURES}"
echo -e "  Updated: ${GREEN}${UPDATED}${NC}"
echo -e "  Skipped: ${YELLOW}${SKIPPED}${NC}"
echo

if [ $UPDATED -gt 0 ]; then
    echo -e "${GREEN}✓ Successfully updated ${UPDATED} test(s)${NC}"
fi
