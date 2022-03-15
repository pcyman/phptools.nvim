local function first_upper(str)
  return (str:gsub("^%l", string.upper))
end

local function build_get_set_table(variable, type)
  return {
    "",
    "    public function get" .. first_upper(variable) .. "(): " .. type,
    "    {",
    "        return $this->" .. variable .. ";",
    "    }",
    "",
    "    public function set" .. first_upper(variable) .. "(" .. type .. " $" .. variable
      .. "): void",
    "    {",
    "        $this->" .. variable .. " = $" .. variable .. ";",
    "    }"
  }
end

local function get_set_for_line(line)
  line = vim.trim(line)
  local _, type, variable = unpack(vim.split(line, ' '))
  variable = string.sub(variable, 2, -2)
  local getset = build_get_set_table(variable, type)
  vim.api.nvim_buf_set_lines(0, -2, -2, true, getset)
end

local M = {}

function M.generate_getset(mode)
  if mode == 'v' then
    local line1 = vim.api.nvim_buf_get_mark(0, "<")[1]
    local line2 = vim.api.nvim_buf_get_mark(0, ">")[1]
    local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, true)
    local re = vim.regex("private ?\\?[a-zA-Z]\\+ \\$[a-zA-Z]\\+;")
    lines = vim.tbl_filter(
      function (line)
        return re:match_str(line)
      end
      ,
      lines
    )
    for _, line in pairs(lines) do
      get_set_for_line(line)
    end
  else
    local line_nr = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(0, line_nr - 1, line_nr, true)[1]
    get_set_for_line(line)
  end
end

return M
