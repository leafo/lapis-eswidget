import Widget, is_mixins_class from require "lapis.html"
import underscore from require "lapis.util"

import types, is_type from require "tableshape"

-- This is support for < lapis 1.11
unless is_mixins_class
  is_mixins_class = (cls) -> rawget(cls, "_mixins_class") == true

import to_json from require "lapis.util"

-- convert bare table to a tableshape object for handling prop_types
-- this supports a lazy prop type that converts functions to types
convert_prop_types = do
  resolve_prop_type = (fn, ...) ->
    if type(fn) == "function"
      fn ...
    else
      fn

  (cls, tbl) ->
    resolved_types = {k, resolve_prop_type(v, k, cls) for k,v in pairs tbl}

    t = types.shape resolved_types, {
      check_all: true
    }

    types.annotate t, {
      format_error: (value, err) => "#{cls.__name}: #{err}"
    }

import RENDER_PROPS_KEY from require "lapis.eswidget.prop_types"

class ESWidget extends Widget
  widget_enclosing_element: "div"

  @widget_name: => underscore @__name or "some_widget"
  @widget_class_name: => "#{@widget_name!}_widget"

  @widget_class_list: =>
    if @ == ESWidget
      return

    if is_mixins_class @
      return @__parent\widget_class_list!

    return @widget_class_name!, @__parent\widget_class_list!

  @asset_packages: {} -- the packages this widget will be placed into

  -- staic ES module initialization
  -- @@es_module: [[]]

  @es_module_init_function_name: => "init_#{@__name}"

  -- this splits apart the js_init into two parts
  -- js_init must be a class method
  @compile_es_module: =>
    -- TODO: how should this work with inheriting?
    return nil, "no @@es_module" unless rawget @, "es_module"

    -- split import and non-import statemetns
    import_lines = {}
    code_lines = {}

    import trim from require "lapis.util"

    assert type(@es_module) == "string", "@es_module must be a string"

    for line in @es_module\gmatch "([^\r\n]+)"
      continue if line\match "^%s*$"

      if line\match "^%s*import"
        table.insert import_lines, trim line
      else
        table.insert code_lines, line

    table.concat {
      table.concat import_lines,  "\n"
      "window.#{@es_module_init_function_name!} = function(widget_selector, widget_params) {"
      table.concat code_lines, "\n"
      "}"
    }, "\n"

  render: (...) =>
    props = @props -- remember props parsed from constructor

    if render_props = @[RENDER_PROPS_KEY]
      helper_scope = setmetatable {}, __index: (helper_scope, name) ->
        -- NOTE: we *must* store the result on scope directly, as that will become the props object
        with v = @_find_helper name
          helper_scope[name] = v
          v

      @props = assert render_props\transform helper_scope

      -- if object was passed through, we need to remove metatable
      if @props == helper_scope
        setmetatable @props, nil

      if props -- merge into newly parsed props, there should be no key conflicts so order doesn't matter
        for k,v in pairs props
          @props[k] = v

    super ...

    -- restore original props object
    @props = props

    return

  new: (props, ...) =>
    if @@prop_types
      @props, state = if is_type @@prop_types
        assert @@prop_types\transform props or {}
      elseif type(@@prop_types) == "table"
        -- lazily convert prop types
        @@prop_types = convert_prop_types @@, @@prop_types
        assert @@prop_types\transform props or {}
      else
        error "Got prop_types of unknown type"

      if render_props = state and state[RENDER_PROPS_KEY]
        @[RENDER_PROPS_KEY] = convert_prop_types @@, render_props

      -- TODO: should we have a method to copy items from props to self?
      -- if state
      --   for k, v in pairs state
      --     if type(k) == "string"
      --       @[k] = v

    else
      super props, ...


  -- unique ID for encloding element
  widget_id: =>
    unless @_widget_id
      @_widget_id = "#{@@widget_name!}_#{math.random 0, 10000000}"
    @_widget_id

  -- a selector that can be used to uniquely find the element on the page
  widget_selector: =>
    "'##{@widget_id!}'"

  js_init: (widget_params=nil) =>
    return nil, "widget does not have an @@es_module" unless rawget @@, "es_module"
    method_name = @@es_module_init_function_name!
    return nil, "no init method name" unless method_name

    "#{method_name}(#{@widget_selector!}, #{to_json widget_params});"

  widget_enclosing_attributes: =>
    {
      id: @widget_id!
      class: { @@widget_class_list! }
    }

  -- NOTE: load order: this will cause inner items to run their js_init before outer elements
  -- this is different than how I've previously done it, where outer runs before inner
  content: (fn=@inner_content) =>
    element @widget_enclosing_element or "div", @widget_enclosing_attributes!, -> fn @

    if js = @js_init!
      if @layout_opts
        @content_for "js_init", ->
          raw js
          unless js\match ";%s*$"
            raw ";"
      else
        script type: "text/javascript", ->
          raw js


  inner_content: =>
