-- TODO: should we also provide the constructor/render params system in this base widget

import Widget, is_mixins_class from require "lapis.html"
import underscore from require "lapis.util"

-- This is support for < lapis 1.11
unless is_mixins_class
  is_mixins_class = (cls) -> rawget(cls, "_mixins_class") == true

import to_json from require "lapis.util"

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

  content: (fn=@inner_content) =>
    classes = { @@widget_class_list! }

    local inner
    el_opts = { id: @widget_id!, class: classes, -> raw inner }

    append_js = if js = @js_init!
      if @layout_opts
        @content_for "js_init", ->
          raw js
          unless js\match ";%s*$"
            raw ";"
        nil
      else
        js

    inner = capture -> fn @
    element @widget_enclosing_element or "div", el_opts

    if append_js
      script type: "text/javascript", ->
        raw append_js


  inner_content: =>
