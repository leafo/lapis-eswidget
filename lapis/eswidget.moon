
import Widget from require "lapis.html"

class ESWidget extends Widget
  @asset_packages: {} -- the packages this widget will be placed into

  @js_init_method_name: => "init_#{@__name}"

  -- this splits apart the js_init into two parts
  -- js_init must be a class method
  @compile_js_init: =>
    -- TODO: how should this work with inheriting?
    return nil, "no @@js_init" unless rawget @, "js_init"

    -- split import and non-import statemetns
    import_lines = {}
    code_lines = {}

    import trim from require "lapis.util"

    for line in @js_init\gmatch "([^\r\n]+)"
      continue if line\match "^%s*$"

      if line\match "^%s*import"
        table.insert import_lines, trim line
      else
        table.insert code_lines, line

    table.concat {
      table.concat import_lines,  "\n"
      "window.#{@js_init_method_name!} = function(widget_selector, widget_params) {"
      table.concat code_lines, "\n"
      "}"
    }, "\n"


  -- staic ES module initialization
  -- @@es_module: [[]]
