local parsed_args = false
return {
  argparser = function()
    parsed_args = true
    local argparse = require("argparse")
    local trim
    trim = require("lapis.util").trim
    local parser = argparse("lapis eswidget", "Widget asset compilation and build generation\nVersion: " .. tostring(require("lapis.eswidget.version")))
    parser:command_target("command")
    parser:flag("--moonscript", "Enable MoonScript module loading")
    local to_array
    to_array = function(str)
      local _accum_0 = { }
      local _len_0 = 1
      for d in str:gmatch("[^,]+") do
        _accum_0[_len_0] = trim(d)
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end
    do
      local _with_0 = parser:command("compile_js", "Compile a single module or entire package to JavaScript")
      _with_0:option("--module")
      _with_0:option("--file")
      _with_0:option("--package")
      _with_0:option("--widget-dirs", "Paths where widgets are located. Only used for compiling by --package"):default("views,widgets"):convert(to_array)
    end
    do
      local _with_0 = parser:command("generate_spec", "Scan widgets and generate specification for compiling bundles")
      _with_0:option("--minify", "Set how minified bundles should be generated"):choices({
        "both",
        "only",
        "none"
      }):default("both")
      _with_0:flag("--skip-bundle", "Skip generated final bundling command")
      _with_0:option("--css-packages", "Instruct build that css files will be generated for listed packages"):convert(to_array)
      _with_0:group("Primary options", _with_0:option("--bundle-method", "What tool to use to bundle the packages"):default("esbuild"):choices({
        "esbuild",
        "module",
        "concat"
      }), _with_0:option("--widget-dirs", "Paths where widgets are located"):default("views,widgets"):convert(to_array), _with_0:option("--format", "Output fromat for generated asset spec file"):choices({
        "json",
        "tup",
        "makefile"
      }):default("json"), _with_0:option("--source-dir", "The working directory for source files (NODE_PATH will be set to this during bundle)"):default("static/js"), _with_0:option("--output-dir", "Destination of final compiled asset packages"):default("static"))
      _with_0:group("esbuild", _with_0:flag("--esbuild-metafile --metafile", "Enable esbuild metafile, creates {output}-metafile.json for every bundled output"), _with_0:option("--esbuild-bin", "Set the path to the esbuild binary. When empty, will use the ESBUILD tup environment variable"), _with_0:option("--esbuild-args", "Append additional arguments to esbuild command"), _with_0:flag("--sourcemap", "Enable sourcemap for bundled outputs (esbuild only)"))
      _with_0:group("tup", _with_0:option("--tup-compile-dep-group", "Dependency group used during the widget -> js compile phase (eg. $(TOP)/<moon>)"), _with_0:option("--tup-bundle-dep-group", "Dependency group used during esbuild bundling phase (eg. $(TOP)/<coffee>)"), _with_0:option("--tup-compile-out-group", "Which group name to place compile output files in (eg. $(TOP)/<modules>)"), _with_0:option("--tup-bundle-out-group", "Which group name to place bundle output files in (eg. $(TOP)/<bundles>)"))
    end
    do
      local _with_0 = parser:command("debug", "Show any extractable information about a widget module")
      _with_0:argument("module_name")
      _with_0:flag("-r --recursive", "Recursively print dependency tree")
    end
    return parser
  end,
  function(self, args, lapis_args)
    assert(parsed_args, "The version of Lapis you are using does not support this version of lapis-systemd. Please upgrade Lapis ≥ v1.14.0")
    local run
    run = require("lapis.eswidget.cmd").run
    return run(args, lapis_args)
  end
}
