local Widget
Widget = require("lapis.html").Widget
local ESWidget
do
  local _class_0
  local _parent_0 = Widget
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "ESWidget",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.asset_packages = { }
  self.js_init_method_name = function(self)
    return "init_" .. tostring(self.__name)
  end
  self.compile_js_init = function(self)
    if not (rawget(self, "js_init")) then
      return nil, "no @@js_init"
    end
    local import_lines = { }
    local code_lines = { }
    local trim
    trim = require("lapis.util").trim
    for line in self.js_init:gmatch("([^\r\n]+)") do
      local _continue_0 = false
      repeat
        if line:match("^%s*$") then
          _continue_0 = true
          break
        end
        if line:match("^%s*import") then
          table.insert(import_lines, trim(line))
        else
          table.insert(code_lines, line)
        end
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    return table.concat({
      table.concat(import_lines, "\n"),
      "window." .. tostring(self:js_init_method_name()) .. " = function(widget_selector, widget_params) {",
      table.concat(code_lines, "\n"),
      "}"
    }, "\n")
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  ESWidget = _class_0
  return _class_0
end
