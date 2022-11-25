local Widget
Widget = require("lapis.html").Widget
local underscore
underscore = require("lapis.util").underscore
local to_json
to_json = require("lapis.util").to_json
local ESWidget
do
  local _class_0
  local _parent_0 = Widget
  local _base_0 = {
    widget_enclosing_element = "div",
    widget_id = function(self)
      if not (self._widget_id) then
        self._widget_id = tostring(self.__class:widget_name()) .. "_" .. tostring(math.random(0, 10000000))
      end
      return self._widget_id
    end,
    widget_selector = function(self)
      return "'#" .. tostring(self:widget_id()) .. "'"
    end,
    js_init = function(self, widget_params)
      if widget_params == nil then
        widget_params = nil
      end
      if not (rawget(self.__class, "es_module")) then
        return nil, "widget does not have an @@es_module"
      end
      local method_name = self.__class:es_module_init_function_name()
      if not (method_name) then
        return nil, "no init method name"
      end
      return tostring(method_name) .. "(" .. tostring(self:widget_selector()) .. ", " .. tostring(to_json(widget_params)) .. ");"
    end,
    content = function(self, fn)
      if fn == nil then
        fn = self.inner_content
      end
      local classes = {
        self.__class:widget_class_list()
      }
      local inner
      local el_opts = {
        id = self:widget_id(),
        class = classes,
        function()
          return raw(inner)
        end
      }
      local append_js
      do
        local js = self:js_init()
        if js then
          if self.layout_opts then
            self:content_for("js_init", function()
              raw(js)
              if not (js:match(";%s$")) then
                return raw(";")
              end
            end)
            append_js = nil
          else
            append_js = js
          end
        end
      end
      inner = capture(function()
        return fn(self)
      end)
      element(self.widget_enclosing_element or "div", el_opts)
      if append_js then
        return script({
          type = "text/javascript"
        }, function()
          return raw(append_js)
        end)
      end
    end,
    inner_content = function(self) end
  }
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
  self.widget_name = function(self)
    return underscore(self.__name or "some_widget")
  end
  self.widget_class_name = function(self)
    return tostring(self:widget_name()) .. "_widget"
  end
  self.widget_class_list = function(self)
    if self == ESWidget then
      return 
    end
    return self:widget_class_name(), self.__parent:widget_class_list()
  end
  self.asset_packages = { }
  self.es_module_init_function_name = function(self)
    return "init_" .. tostring(self.__name)
  end
  self.compile_es_module = function(self)
    if not (rawget(self, "es_module")) then
      return nil, "no @@es_module"
    end
    local import_lines = { }
    local code_lines = { }
    local trim
    trim = require("lapis.util").trim
    assert(type(self.es_module) == "string", "@es_module must be a string")
    for line in self.es_module:gmatch("([^\r\n]+)") do
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
      "window." .. tostring(self:es_module_init_function_name()) .. " = function(widget_selector, widget_params) {",
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
