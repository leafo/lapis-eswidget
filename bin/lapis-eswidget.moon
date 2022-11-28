
argparse = require "argparse"
import trim from require "lapis.util"

parser = argparse "widget_helper.moon",
  "Widget asset compilation and build generation"

parser\command_target "command"

parser\flag "--moonscript", "Enable MoonScript module loading"

to_array = (str) -> [trim(d) for d in str\gmatch "[^,]+"]

with parser\command "debug", "Show any extractable information about a widget module"
  \argument "module_name"

with parser\command "compile_js", "Compile the individual js_init function for a module"
  \option("--module")
  \option("--file")
  \option("--package")
  \option("--widget-dirs", "Paths where widgets are located. Only used for compiling by --package")\default("views,widgets")\convert to_array

with parser\command "generate_spec", "Scan widgets and generate specification for compiling bundles"
  \option("--widget-dirs", "Paths where widgets are located")\default("views,widgets")\convert to_array

  \option("--format", "Output fromat for generated asset spec file")\choices({"json", "tup", "makefile"})\default "json"
  \option("--minify", "Set how minified bundles should be generated")\choices({"both", "only", "none"})\default "both"
  \flag("--sourcemap", "Enable sourcemap for bundled outputs")

  \option("--source-dir", "The working directory for source files (Will be set to NODE_PATH for build)")\default "static/js"
  \option("--output-dir", "Destination of final compiled asset packages")\default "static"
  \option("--esbuild-bin", "Set the path to the esbuild binary. When empty, will use the ESBUILD tup environment variable")

  -- these are the tup order-only dependency groups for various stages of building
  \option("--tup-compile-dep-group", "Dependency group used during the widget -> js compile phase (eg. $(TOP)/<moon>)")
  \option("--tup-bundle-dep-group", "Dependency group used during esbuild bundling phase (eg. $(TOP)/<coffee>)")

args = parser\parse [v for _, v in ipairs _G.arg]

import run from require("lapis.eswidget.cmd")

run args

