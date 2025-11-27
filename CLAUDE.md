## Project overview
This is a tree-sitter grammar for the Fram experimental research language.
Fram uses an ML-like grammar.
More info on Fram, and its current implementation, `dbl`: https://github.com/fram-lang/dbl

You can access dbl in directory `../dbl/`

Fram requires an external tokenizer to parse comments, see `src/scanner.c`
Grammar is written in `./grammar.js`, the rest of files is largely unimportant.

## Development
- this uses a nix dev environment to manage dependencies
    * same goes for `../dbl/`
- we have two test kinds:
    * built-in tree-sitter unit tests
    * `scripts/test_if_parses.sh`, which runs all files from `dbl` test suite to check if they parse successfuly, but without checking the result itself
- `scripts/generate_dbl_tests.sh` generates tree-sitter test corpus from dbl test suite files in `./test/corpus/expect_dbl/`
    * creates test files with empty expected parse trees to be filled in manually
    * skips files if the source content matches existing test
    * prompts before overwriting tests with different source content
- `scripts/update_expect_tests.sh` runs the expect test suite and for each failing test
    * shows the diff of current/expected and prompts the user to verify the output
    * if accepted, runs `tree-sitter`'s built in update on the single test.

## Important commands

- `nix develop`
- `scripts/generate_dbl_tests.sh` - generate test corpus from dbl test suite
- `scripts/test_if_parses.sh ../dbl/test/ok/* | grep failed`
- `tree-sitter generate`
- `tree-sitter build`
- `tree-sitter test`
- `tree-sitter parse`
