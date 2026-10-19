-- Run with: nvim --headless -u NONE -l scripts/test_editor.lua /path/to/fram.so ../fram.nvim
vim.opt.runtimepath:prepend(arg[2] or "../fram.nvim")
vim.treesitter.language.add("fram", { path = assert(arg[1], "parser library required") })

local function parse(source)
  local parser = vim.treesitter.get_string_parser(source, "fram")
  local root = parser:parse()[1]:root()
  assert(not root:has_error(), source .. "\n" .. root:sexpr())
  return root
end

local function find(root, kind)
  local result = {}
  local function visit(node)
    if node:type() == kind then result[#result + 1] = node end
    for child in node:iter_children() do visit(child) end
  end
  visit(root)
  return result
end

local function expression(source)
  local root = parse("let x = " .. source)
  return find(root, "def_let")[1]:named_child(1)
end

local function shape(node, source)
  if node:type() == "ex_binop" then
    return "(" .. vim.treesitter.get_node_text(node:named_child(1), source)
      .. " " .. shape(node:named_child(0), source)
      .. " " .. shape(node:named_child(2), source) .. ")"
  elseif node:type() == "ex_app" then
    local parts = { "app" }
    for child in node:iter_children() do
      if child:named() then parts[#parts + 1] = shape(child, source) end
    end
    return "(" .. table.concat(parts, " ") .. ")"
  end
  return vim.treesitter.get_node_text(node, source)
end

for _, case in ipairs({
  { "a + b * c", "(+ a (* b c))" },
  { "a * b + c", "(+ (* a b) c)" },
  { "a - b - c", "(- (- a b) c)" },
  { "a :: b :: c", "(:: a (:: b c))" },
  { "a || b || c", "(|| a (|| b c))" },
  { "a && b || c", "(|| (&& a b) c)" },
  { "a <- b <- c", "(<- a (<- b c))" },
  { "a := b := c", "(:= a (:= b c))" },
  { "a ** b ** c", "(** a (** b c))" },
  { "a / b * c", "(* (/ a b) c)" },
  { "a; b; c", "(; a (; b c))" },
  { "a, b, c", "(, (, a b) c)" },
  { "f x + g y", "(+ (app f x) (app g y))" },
}) do
  local source = "let x = " .. case[1]
  local actual = shape(expression(case[1]), source)
  assert(actual == case[2], case[1] .. ": " .. actual .. " ~= " .. case[2])
end

local nested_if = expression("if a then if b then c else d")
assert(nested_if:type() == "ex_if_no_else")
assert(nested_if:named_child(1):type() == "ex_if")
assert(#find(parse("let x = [a, b, c]"), "ex_binop") == 0)
assert(#find(parse("let x = {a = f x, b = fn y => y, c = a; b}"), "fld_nameval") == 3)
assert(#find(parse("let f = fn (A | B) => match x with | (A | B) => C end"), "ex_or_pattern") == 2)
local invalid_pattern = vim.treesitter.get_string_parser("let x = A | B", "fram"):parse()[1]:root()
assert(invalid_pattern:has_error(), "or-pattern accepted outside a pattern")
for _, source in ipairs({ "let x = a => b", "let x = a -> b", "let x = a ->> b",
  "let x = a = b", "let x = ? a", "let x = ~ a", 'let x = "bad \\q"' }) do
  assert(vim.treesitter.get_string_parser(source, "fram"):parse()[1]:root():has_error(), source)
end
assert(#find(parse("let x = M.N.x let c = M.N.C"), "ex_select") == 2)

local strings = [=[let x = "# {# text #} \\ \" \x41
\{ foo "nested \{ bar }" | fmt {x=1}}!"]=]
local string_root = parse(strings)
assert(#find(string_root, "interpolation") == 2)
assert(#find(string_root, "block_comment") == 0)
assert(#find(string_root, "line_comment") == 0)
parse("let x = 'a' let y = '\\x41' let z = '\\n'")
parse("# comment at EOF")
parse("## documentation at EOF")

for _, tag in ipairs({ "", "#", "aba", string.rep("long", 30), string.rep("λ", 40) }) do
  local source = "{#" .. tag .. " body {#not_nested wrong#} " .. tag .. "#}\nlet x = 1"
  local root = parse(source)
  assert(#find(root, "block_comment") == 1, tag)
  assert(#find(root, "def_let") == 1, tag)
end
local unfinished = parse("{#tag unfinished")
assert(#find(unfinished, "block_comment_unfinished") == 1)

local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "{#tag body tag#}", "let x = 1" })
local parser = vim.treesitter.get_parser(bufnr, "fram")
local function check_incremental()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local source = table.concat(lines, "\n") .. "\n"
  local incremental = parser:parse()[1]:root():sexpr()
  local fresh = vim.treesitter.get_string_parser(source, "fram"):parse()[1]:root():sexpr()
  assert(incremental == fresh, "incremental tree differs from fresh parse")
end
check_incremental()
vim.api.nvim_buf_set_text(bufnr, 0, 2, 0, 5, { "longtag" })
check_incremental()
vim.api.nvim_buf_set_text(bufnr, 0, 15, 0, 18, { "longtag" })
check_incremental()
assert(#find(parser:parse()[1]:root(), "def_let") == 1, "closing tag did not restore code")
vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { '{#tag body tag#}', 'let s = "# \\{ x }"' })
check_incremental()
vim.treesitter.start(bufnr, "fram")
assert(vim.treesitter.highlighter.active[bufnr], "buffer highlighter did not start")
vim.api.nvim_buf_delete(bufnr, { force = true })

local query_paths = { "queries/highlights.scm", (arg[2] or "../fram.nvim") .. "/queries/fram/highlights.scm" }
local query_source
for _, path in ipairs(query_paths) do
  local text = table.concat(vim.fn.readfile(path), "\n")
  if query_source then assert(text == query_source, "plugin and grammar queries differ") end
  query_source = text
  local query = vim.treesitter.query.parse("fram", text)
  local source = 'pub let f x (z : Int) = "text \\{ g y }" let binding = callee argument method m p = body'
  local captures = {}
  for id, node in query:iter_captures(parse(source), source) do
    local key = query.captures[id] .. ":" .. vim.treesitter.get_node_text(node, source)
    captures[key] = true
  end
  assert(captures["keyword:let"])
  assert(captures["function:f"])
  assert(captures["variable.parameter:x"])
  assert(captures["variable.parameter:z"])
  assert(not captures["variable.parameter:argument"], "call argument highlighted as a definition parameter")
  assert(captures["function.method:m"])
  assert(not captures["function.method:body"], "method body highlighted as a method name")
  assert(captures["string:text "])
  assert(captures["punctuation.special:\\{"])
  assert(not captures['string:"text \\{ g y }"'], "interpolation is highlighted as plain string")

  local punctuation_source = [=[@{test}
type F = (_ ->[_] _) ->> {x : Int}
let f = fn (x : Int) => match x with | y => {x=y, xs=[1,2]} end
let g = value >.run
let h = M.x
let eff = effect () / r => r ()
let s = "([]{} -> ->> => : , . | = / >.)"
# ([]{} -> ->> => : , . | = / >.)
]=]
  local punctuation = {}
  for id, node in query:iter_captures(parse(punctuation_source), punctuation_source) do
    local capture = query.captures[id]
    if capture == "operator" or capture:match("^punctuation%.") then
      local parent = node
      while parent do
        assert(parent:type() ~= "str" and not parent:type():match("comment"),
          "punctuation captured inside a string or comment")
        parent = parent:parent()
      end
      punctuation[capture .. ":" .. vim.treesitter.get_node_text(node, punctuation_source)] = true
    end
  end
  for _, bracket in ipairs({ "(", ")", "[", "]", "{", "}", "@{" }) do
    assert(punctuation["punctuation.bracket:" .. bracket], "missing bracket: " .. bracket)
  end
  for _, delimiter in ipairs({ ",", ".", ":" }) do
    assert(punctuation["punctuation.delimiter:" .. delimiter], "missing delimiter: " .. delimiter)
  end
  for _, operator in ipairs({ "=", "|", "/", "->", "->>", "=>", ">." }) do
    assert(punctuation["operator:" .. operator], "missing operator: " .. operator)
  end
end

local parsers = {}
package.loaded["nvim-treesitter.parsers"] = { get_parser_configs = function() return parsers end }
package.path = (arg[2] or "../fram.nvim") .. "/lua/?.lua;" .. package.path
require("fram").setup()
assert(parsers.fram.install_info.revision == nil)
assert(parsers.fram.install_info.branch == "main")
assert(parsers.fram.install_info.url == "https://github.com/Foxinio/tree-sitter-fram")
print("Fram structure, scanner, incremental parsing, highlights, and plugin checks passed")
