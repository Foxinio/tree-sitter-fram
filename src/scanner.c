#include "tree_sitter/parser.h"
#include "tree_sitter/alloc.h"
#include <stdint.h>
#include <string.h>

enum TokenType {
    BLOCK_COMMENT,
    BLOCK_COMMENT_UNFINISHED,
    ERROR_SENTINEL,
    STRING_CONTENT,
    OP_0, OP_20, OP_30, OP_40, OP_50, OP_60, OP_70, OP_80, OP_90, OP_100,
};

void *tree_sitter_fram_external_scanner_create(void) { return NULL; }
void tree_sitter_fram_external_scanner_destroy(void *payload) { (void)payload; }
unsigned tree_sitter_fram_external_scanner_serialize(void *payload, char *buffer) {
    (void)payload;
    (void)buffer;
    return 0;
}
void tree_sitter_fram_external_scanner_deserialize(void *payload, const char *buffer, unsigned length) {
    (void)payload;
    (void)buffer;
    (void)length;
}

static void advance(TSLexer *lexer) { lexer->advance(lexer, false); }

static bool is_tag_char(int32_t c) {
    return c > 32 && c != 127 && c != '{' && c != '}';
}

static bool is_op_char(int32_t c) {
    return c > 0 && c < 128 && strchr("<>&$?!@^+~*%;,=|:./-", c) != NULL;
}

static bool scan_operator(TSLexer *lexer, const bool *valid_symbols) {
    int32_t first = lexer->lookahead, second = 0, third = 0;
    size_t length = 0;
    while (is_op_char(lexer->lookahead)) {
        if (length == 1) second = lexer->lookahead;
        if (length == 2) third = lexer->lookahead;
        length++;
        advance(lexer);
    }
    // Reserved punctuation must stay reserved even where only an operator fits.
    if (length == 1 && strchr("?:~|=,./", first)) return false;
    if (length == 1 && first == '@' && lexer->lookahead == '{') return false;
    if (length == 2 && ((first == '-' && second == '>') ||
        (first == '=' && second == '>') || (first == '>' && second == '.') ||
        (first == ';' && second == ';'))) return false;
    if (length == 3 && first == '-' && second == '>' && third == '>') return false;
    enum TokenType token;
    if (first == ';') token = OP_0;
    else if ((first == '<' && second == '-') || (first == ':' && second == '=')) token = OP_20;
    else if (first == ',') token = OP_30;
    else if (first == '|' && second == '|') token = OP_40;
    else if (first == '&' && second == '&') token = OP_50;
    else if (strchr("!=<>|&$?", first)) token = OP_60;
    else if (strchr("@:^", first)) token = OP_70;
    else if (strchr("+-~", first)) token = OP_80;
    else if (first == '*' && second == '*') token = OP_100;
    else token = OP_90;
    if (!valid_symbols[token]) return false;
    lexer->result_symbol = token;
    return true;
}

bool tree_sitter_fram_external_scanner_scan(void *payload, TSLexer *lexer, const bool *valid_symbols) {
    (void)payload;
    if (valid_symbols[ERROR_SENTINEL]) return false;
    if (valid_symbols[STRING_CONTENT]) {
        bool consumed = false;
        while (!lexer->eof(lexer) && lexer->lookahead != '"' && lexer->lookahead != '\\') {
            advance(lexer);
            consumed = true;
        }
        if (consumed) {
            lexer->result_symbol = STRING_CONTENT;
            return true;
        }
    }
    while (lexer->lookahead == ' ' || (lexer->lookahead >= '\t' && lexer->lookahead <= '\r')) {
        lexer->advance(lexer, true);
    }
    if (is_op_char(lexer->lookahead)) {
        bool operator_valid = false;
        for (unsigned i = OP_0; i <= OP_100; i++) operator_valid |= valid_symbols[i];
        return operator_valid && scan_operator(lexer, valid_symbols);
    }
    if (!valid_symbols[BLOCK_COMMENT]) return false;
    if (lexer->lookahead != '{') return false;
    advance(lexer);
    if (lexer->lookahead != '#') return false;
    advance(lexer);

    // Scan each comment as one token so arbitrary tags need no serialized state.
    size_t capacity = 32, length = 0;
    int32_t *tag = ts_malloc(capacity * sizeof(int32_t));
    while (!lexer->eof(lexer) && is_tag_char(lexer->lookahead)) {
        if (length == capacity) {
            capacity *= 2;
            tag = ts_realloc(tag, capacity * sizeof(int32_t));
        }
        tag[length++] = lexer->lookahead;
        advance(lexer);
    }
    size_t width = length + 2;
    int32_t *window = ts_calloc(width, sizeof(int32_t));
    size_t index = 0, consumed = 0;
    lexer->result_symbol = BLOCK_COMMENT_UNFINISHED;
    while (!lexer->eof(lexer)) {
        int32_t c = lexer->lookahead;
        window[index] = c;
        index = (index + 1) % width;
        if (consumed < width) consumed++;
        advance(lexer);
        if (c != '}' || consumed < width || window[(index + length) % width] != '#') continue;
        size_t matched = 0;
        while (matched < length && window[(index + matched) % width] == tag[matched]) matched++;
        if (matched == length) {
            lexer->result_symbol = BLOCK_COMMENT;
            break;
        }
    }
    ts_free(window);
    ts_free(tag);
    return true;
}
