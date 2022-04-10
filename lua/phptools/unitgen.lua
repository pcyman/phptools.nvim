local q = require("vim.treesitter.query")

local function build_unit_test_table(vars, class, constructor_vars, imports, namespace)
  local unit_test = {
    "<?php",
    "",
    "declare(strict_types=1);",
    "",
  }
  table.insert(unit_test, "namespace " .. namespace .. ";")
  table.insert(unit_test, "")
  for _, import in pairs(imports) do
    table.insert(unit_test, "use " .. import .. ";")
  end
  table.insert(unit_test, "")
  table.insert(unit_test, "class " .. class .. "Test extends TestCase")
  table.insert(unit_test, "{")
  table.insert(unit_test, "    use ProphecyTrait;")
  table.insert(unit_test, "")
  for _, var in pairs(vars) do
    table.insert(unit_test, "    /** @var " .. var.var_type .. "|ObjectProphecy */")
    table.insert(unit_test, "    private $" .. var.var_name .. ";")
    table.insert(unit_test, "")
  end
  table.insert(unit_test, "    private " .. class .. " $sut;")
  table.insert(unit_test, "")
  table.insert(unit_test, "    public function setUp(): void")
  table.insert(unit_test, "    {")
  for _, var in pairs(constructor_vars) do
    table.insert(unit_test, "        $this->" .. var.var_name .. " = $this->get" .. var.var_type .. "Mock();")
  end
  table.insert(unit_test, "")
  table.insert(unit_test, "        $this->sut = new " .. class .. "(")
  for id, var in pairs(constructor_vars) do
    if (id == vim.tbl_count(constructor_vars)) then
      table.insert(unit_test, "            $this->" .. var.var_name .. "->reveal()")
    else
      table.insert(unit_test, "            $this->" .. var.var_name .. "->reveal(),")
    end
  end
  table.insert(unit_test, "        );")
  table.insert(unit_test, "    }")
  table.insert(unit_test, "")
  table.insert(unit_test, "    /** @test */")
  table.insert(unit_test, "    public function shouldExecute(): void")
  table.insert(unit_test, "    {")
  table.insert(unit_test, "        $this->assertTrue(true);")
  table.insert(unit_test, "    }")
  for _, var in pairs(vars) do
    table.insert(unit_test, "")
    table.insert(unit_test, "    private function get" .. var.var_type .. "Mock(): ObjectProphecy")
    table.insert(unit_test, "    {")
    table.insert(unit_test, "        /** @var " .. var.var_type .. "|ObjectProphecy */")
    table.insert(unit_test, "        $mock = $this->prophesize(" .. var.var_type .. "::class);")
    table.insert(unit_test, "")
    table.insert(unit_test, "        return $mock;")
    table.insert(unit_test, "    }")
  end
  table.insert(unit_test, "}")
  return unit_test
end

local function get_vars_with_types(php_ts_root)
  local query = vim.treesitter.parse_query("php", [[
  (property_declaration 
      type: (union_type (named_type) @var_type)
      (property_element
          (variable_name (name) @var_name))
  )
  ]])
  local vars = {}
  for _, captures, _ in query:iter_matches(php_ts_root, 0) do
    local var_type = q.get_node_text(captures[1], 0)
    local var_name = q.get_node_text(captures[2], 0)
    table.insert(vars, {var_type = var_type, var_name = var_name})
  end

  return vars
end

local function get_class_name(php_ts_root)
  local query = vim.treesitter.parse_query("php", [[
  (class_declaration 
      name: (name) @class_name
  )
  ]])
  local class_name = ""
  for _, captures, _ in query:iter_matches(php_ts_root, 0) do
    class_name = q.get_node_text(captures[1], 0)
  end

  return class_name
end

local function get_constructor_vars(php_ts_root)
  local query = vim.treesitter.parse_query("php", [[
  (method_declaration
      name: (name) @method_name (#eq? @method_name "__construct")
      parameters: (formal_parameters (
          (simple_parameter 
              type: (union_type (named_type (name) @var_type))
              name: (variable_name (name) @var_name)
          )
      ))
  )
  ]])
  local constructor_vars = {}
  for _, captures, _ in query:iter_matches(php_ts_root, 0) do
    local var_type = q.get_node_text(captures[2], 0)
    local var_name = q.get_node_text(captures[3], 0)
    table.insert(constructor_vars, {var_type = var_type, var_name = var_name})
  end

  return constructor_vars
end

local function get_current_namespace(php_ts_root)
  local query = vim.treesitter.parse_query("php", [[
  (namespace_definition
      name: (namespace_name) @ns
  )
  ]])
  local namespace = ""
  for _, captures, _ in query:iter_matches(php_ts_root, 0) do
    namespace = q.get_node_text(captures[1], 0)
  end

  return namespace
end

local function get_php_ts_root()
  local parser = vim.treesitter.get_parser(0, "php")
  local tstree = parser:parse()
  local root = tstree[1]:root()

  return root
end

local function get_composer_ts_root_and_buf()
  local composer_contents = vim.api.nvim_exec("!cat composer.json", true)
  local composer_content_table = {}
  for str in string.gmatch(composer_contents, "([^\n]*)\n?") do
    table.insert(composer_content_table, str)
  end
  table.remove(composer_content_table, 1)
  local composer_buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_lines(composer_buf, 1, -1, true, composer_content_table)
  local json_parser = vim.treesitter.get_parser(composer_buf, "json")
  local composer_tstree = json_parser:parse()
  local composer_root = composer_tstree[1]:root()

  return composer_root, composer_buf
end

local function get_test_namespace(namespace)
  -- get class namespace prefix
  local composer_root, composer_buf = get_composer_ts_root_and_buf()
  local query = vim.treesitter.parse_query("json", [[
  (pair
      key: (string (string_content) @psr) (#eq? @psr "psr-4")
      value: (object (pair 
          key: (string (string_content) @prefix)
          value: (string (string_content) @src_path (#eq? @src_path "src/"))
      ))
  )
  ]])
  local class_ns_prefix = ""
  for _, captures, _ in query:iter_matches(composer_root, composer_buf) do
    class_ns_prefix = q.get_node_text(captures[2], composer_buf)
  end

  -- get tests namespace prefix
  query = vim.treesitter.parse_query("json", [[
  (pair
      key: (string (string_content) @psr) (#eq? @psr "psr-4")
      value: (object (pair 
          key: (string (string_content) @prefix)
          value: (string (string_content) @src_path (#eq? @src_path "tests/"))
      ))
  )
  ]])
  local tests_ns_prefix = ""
  for _, captures, _ in query:iter_matches(composer_root, composer_buf) do
    tests_ns_prefix = q.get_node_text(captures[2], composer_buf)
  end

  class_ns_prefix = string.gsub(class_ns_prefix, '\\\\', '\\')
  tests_ns_prefix = string.gsub(tests_ns_prefix, '\\\\', '\\')
  local test_namespace = string.gsub(namespace, class_ns_prefix, tests_ns_prefix)
  vim.api.nvim_buf_delete(composer_buf, {force = true})

  return test_namespace
end

local function get_imports(namespace, class_name, constructor_vars, php_ts_root)
  local imports = {}
  for _, var in pairs(constructor_vars) do
    local query_str = [[
    (namespace_use_clause 
        (qualified_name 
            (name) @class (#eq? @class "]]
    query_str = query_str .. var.var_type .. "\")) @use)"
    local query = vim.treesitter.parse_query("php", query_str)
    for _, captures, _ in query:iter_matches(php_ts_root, 0) do
      table.insert(imports, q.get_node_text(captures[2], 0))
    end
  end
  table.insert(imports, "PHPUnit\\Framework\\TestCase")
  table.insert(imports, "Prophecy\\Prophecy\\ObjectProphecy")
  table.insert(imports, "Prophecy\\PhpUnit\\ProphecyTrait")
  table.insert(imports, namespace .. "\\" .. class_name)
  table.sort(imports)

  return imports
end

local M = {}

function M.generate_test()
  local php_ts_root = get_php_ts_root()
  local vars = get_vars_with_types(php_ts_root)
  local class_name = get_class_name(php_ts_root)
  local constructor_vars = get_constructor_vars(php_ts_root)
  local namespace = get_current_namespace(php_ts_root)
  local test_namespace = get_test_namespace(namespace)
  local imports = get_imports(namespace, class_name, constructor_vars, php_ts_root)

  -- create buffer and window
  local unit_test_table = build_unit_test_table(vars, class_name, constructor_vars, imports, test_namespace)
  local buffer = vim.api.nvim_create_buf(true, false)
  local current_name = vim.api.nvim_buf_get_name(0)
  local test_name = string.gsub(current_name, "/src/", "/tests/")
  test_name = string.gsub(test_name, ".php", "Test.php")
  -- create directory for test if doesn't exist
  local test_path = test_name:match('(.*/)')
  vim.api.nvim_command('call mkdir(\'' .. test_path .. '\', \'p\')')
  vim.api.nvim_command('vsplit')
  vim.api.nvim_buf_set_name(buffer, test_name)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, true, unit_test_table)
  vim.api.nvim_win_set_buf(0, buffer)
end

return M
