
parsed_args = false

{
  argparser: ->
    parsed_args = true

    argparse = require "argparse"
    import trim from require "lapis.util"

    parser = argparse "lapis eswidget",
      "Widget asset compilation and build generation\nVersion: #{require "lapis.eswidget.version"}"

    parser\command_target "command"

    parser\flag "--moonscript", "Enable MoonScript module loading"

    to_array = (str) -> [trim(d) for d in str\gmatch "[^,]+"]

    with parser\command "compile_js", "Compile a single module or entire package to JavaScript"
      \option("--module")
      \option("--file")
      \option("--package")
      \option("--widget-dirs", "Paths where widgets are located. Only used for compiling by --package")\default("views,widgets")\convert to_array

    with parser\command "compile_css", "Compile scoped CSS for a single widget"
      \option("--module", "Load by Lua module name")
      \option("--file", "Load by filename of a Lua module")

    with parser\command "generate_spec", "Scan widgets and generate specification for compiling bundles"
      \option("--minify", "Set how minified bundles should be generated")\choices({"both", "only", "none"})\default "both"
      \flag("--skip-bundle", "Skip generated final bundling command")
      \option("--css-packages", "Instruct build that css files will be generated for listed packages")\convert to_array

      \group("Primary options"
        \option("--bundle-method", "What tool to use to bundle the packages")\default("esbuild")\choices {"esbuild", "module", "concat"}
        \option("--widget-dirs", "Paths where widgets are located")\default("views,widgets")\convert to_array
        \option("--format", "Output fromat for generated asset spec file")\choices({"json", "tup", "makefile"})\default "json"
        \option("--source-dir", "The working directory for source files (NODE_PATH will be set to this during bundle)")\default "static/js"
        \option("--output-dir", "Destination of final compiled asset packages")\default "static"
      )

      \group("esbuild"
        \flag("--esbuild-metafile --metafile", "Enable esbuild metafile, creates {output}-metafile.json for every bundled output")
        \option("--esbuild-bin", "Set the path to the esbuild binary. When empty, will use the ESBUILD tup environment variable")
        \option("--esbuild-args", "Append additional arguments to esbuild command")

        \flag("--sourcemap", "Enable sourcemap for bundled outputs (esbuild only)")
      )

      -- these are the tup order-only dependency groups for various stages of building
      \group("tup"
        \option("--tup-compile-dep-group", "Dependency group used during the widget -> js compile phase (eg. $(TOP)/<moon>)")
        \option("--tup-bundle-dep-group", "Dependency group used during esbuild bundling phase (eg. $(TOP)/<coffee>)")

        \option("--tup-compile-out-group", "Which group name to place compile output files in (eg. $(TOP)/<modules>)")
        \option("--tup-bundle-out-group", "Which group name to place bundle output files in (eg. $(TOP)/<bundles>)")
      )

    with parser\command "debug", "Show any extractable information about a widget module"
      \argument "module_name"
      \flag("-r --recursive", "Recursively print dependency tree")

    parser

  (args, lapis_args) =>
    assert parsed_args,
      "The version of Lapis you are using does not support this version of lapis-systemd. Please upgrade Lapis ≥ v1.14.0"

    import run from require("lapis.eswidget.cmd")
    run args, lapis_args
}
