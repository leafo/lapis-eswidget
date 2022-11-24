-- TODO: should we also provide the constructor/render params system in this base widget

import Widget from require "lapis.html"
import underscore from require "lapis.util"

import to_json from require "lapis.util"

class ESWidget extends Widget
  @widget_name: => underscore @__name or "some_widget"
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
      @_opts.id or= @_widget_id if @_opts
    @_widget_id

  -- a selector that can be used to uniquely find the element on the page
  widget_selector: =>
    "'##{@widget_id!}'"

  js_init: (widget_params=nil) =>
    return nil, "widget does not have an @@es_module" unless rawget @@, "es_module"
    method_name = @@es_module_init_function_name!
    return nil, "no init method name" unless method_name

    "#{method_name}(#{@widget_selector!}, #{to_json widget_params});"
