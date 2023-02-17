local Widget, is_mixins_class
do
  local _obj_0 = require("lapis.html")
  Widget, is_mixins_class = _obj_0.Widget, _obj_0.is_mixins_class
end
local underscore
underscore = require("lapis.util").underscore
local types, is_type
do
  local _obj_0 = require("tableshape")
  types, is_type = _obj_0.types, _obj_0.is_type
end
if not (is_mixins_class) then
  is_mixins_class = function(cls)
    return rawget(cls, "_mixins_class") == true
  end
end
local to_json
to_json = require("lapis.util").to_json
local convert_prop_types
do
  local resolve_prop_type
  resolve_prop_type = function(fn, ...)
    if type(fn) == "function" then
      return fn(...)
    else
      return fn
    end
  end
  convert_prop_types = function(cls, tbl)
    local resolved_types
    do
      local _tbl_0 = { }
      for k, v in pairs(tbl) do
        _tbl_0[k] = resolve_prop_type(v, k, cls)
      end
      resolved_types = _tbl_0
    end
    local t = types.shape(resolved_types, {
      check_all = true
    })
    return types.annotate(t, {
      format_error = function(self, value, err)
        return tostring(cls.__name) .. ": " .. tostring(err)
      end
    })
  end
end
local RENDER_PROPS_KEY
RENDER_PROPS_KEY = require("lapis.eswidget.prop_types").RENDER_PROPS_KEY
local ESWidget
do
  local _class_0
  local _parent_0 = Widget
  local _base_0 = {
    widget_enclosing_element = "div",
    render = function(self, ...)
      local props = self.props
      do
        local render_props = self[RENDER_PROPS_KEY]
        if render_props then
          local helper_scope = setmetatable({ }, {
            __index = function(helper_scope, name)
              do
                local v = self:_find_helper(name)
                helper_scope[name] = v
                local _ = v
                return v
              end
            end
          })
          self.props = assert(render_props:transform(helper_scope))
          if self.props == helper_scope then
            setmetatable(self.props, nil)
          end
          if props then
            for k, v in pairs(props) do
              self.props[k] = v
            end
          end
        end
      end
      _class_0.__parent.__base.render(self, ...)
      self.props = props
    end,
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
    widget_enclosing_attributes = function(self)
      return {
        id = self:widget_id(),
        class = {
          self.__class:widget_class_list()
        }
      }
    end,
    content = function(self, fn)
      if fn == nil then
        fn = self.inner_content
      end
      if self.widget_enclosing_element == false then
        fn(self)
      else
        element(self.widget_enclosing_element, self:widget_enclosing_attributes(), function()
          return fn(self)
        end)
      end
      return self:render_js_init()
    end,
    render_js_init = function(self)
      local js = self:js_init()
      if not (js) then
        return 
      end
      if self.layout_opts then
        return self:content_for("js_init", function()
          raw(js)
          if not (js:match(";%s*$")) then
            return raw(";")
          end
        end)
      else
        return script({
          type = "text/javascript"
        }, function()
          return raw(js)
        end)
      end
    end,
    inner_content = function(self) end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, props, ...)
      if self.__class.prop_types then
        local state
        if is_type(self.__class.prop_types) then
          self.props, state = assert(self.__class.prop_types:transform(props or { }))
        elseif type(self.__class.prop_types) == "table" then
          self.__class.prop_types = convert_prop_types(self.__class, self.__class.prop_types)
          self.props, state = assert(self.__class.prop_types:transform(props or { }))
        else
          self.props, state = error("Got prop_types of unknown type")
        end
        do
          local render_props = state and state[RENDER_PROPS_KEY]
          if render_props then
            self[RENDER_PROPS_KEY] = convert_prop_types(self.__class, render_props)
          end
        end
      else
        return _class_0.__parent.__init(self, props, ...)
      end
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
    if is_mixins_class(self) then
      return self.__parent:widget_class_list()
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
