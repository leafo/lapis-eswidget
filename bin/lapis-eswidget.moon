
argparse = require "argparse"
import trim from require "lapis.util"

parser = argparse "widget_helper.moon",
  "Widget asset compilation and build generation"

parser\command_target "command"

parser\flag "--moonscript", "Enable MoonScript module loading"

with parser\command "debug", "Show any extractable information about a widget module"
  \argument "module_name"

with parser\command "compile_js", "Compile the individual js_init function for a module"
  \option("--module")
  \option("--file")
  \option("--package")

with parser\command "generate_spec", "Scan widgets and generate specification for compiling bundles"
  \option("--widget-dirs")\default("views,widgets")\convert (str) ->
    [trim(d) for d in str\gmatch "[^,]+"]

  \option("--format", "Output format for scan results")\choices({"json", "tup"})\default "json"

args = parser\parse [v for _, v in ipairs _G.arg]

import run from require("lapis.eswidget.cmd")

run args

