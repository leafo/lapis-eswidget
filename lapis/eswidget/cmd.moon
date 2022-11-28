import types from require "tableshape"
import subclass_of from require "tableshape.moonscript"

import shell_escape, join from require "lapis.cmd.path"

-- we reference the module so we can overwrite these methods when running in
-- test suite
_M = {
  print: print
  print_warning: (msg) ->
    io.stderr\write msg
    io.stderr\write "\n"
}

-- quote shell escapes str if necessary
shell_quote = (str) ->
  if str\match "'"
    "'#{shell_escape str}'"
  else
    str

-- args should come from parsed argparse result
_M.run = (args) ->
  print = (...) -> _M.print ...
  search_extension = "lua"

  if args.moonscript
    search_extension = "moon"
    require "moonscript"

  -- eg. widgets/community/post_list.moon --> widgets.community.post_list
  path_to_module = (path) ->
    (path\gsub("%.#{search_extension}$", "")\gsub("/+", "."))

  each_module_file = do
    scan_prefix = (...) ->
      prefixes = {...}

      lfs = require "lfs"

      for prefix in *prefixes
        subdirs = {}

        for file in lfs.dir prefix
          continue if file == "."
          continue if file == ".."

          full_path = "#{prefix}/#{file}"
          attr = lfs.attributes full_path
          continue unless attr

          if attr.mode == "directory"
            table.insert subdirs, full_path
          else
            if full_path\match "%.#{search_extension}$"
              coroutine.yield full_path

        scan_prefix unpack subdirs

    (...) ->
      prefixes = {...}
      coroutine.wrap -> scan_prefix unpack prefixes


  each_widget = ->
    coroutine.wrap ->
      is_widget = subclass_of require "lapis.eswidget"

      for file in each_module_file unpack args.widget_dirs
        module_name = path_to_module file
        widget = require module_name
        continue unless is_widget widget

        unless widget.asset_packages
          _M.print_warning "Widget without @asset_packages"
          continue

        coroutine.yield {
          :file
          module_name: path_to_module file
          :widget
        }

  switch args.command
    when "compile_js"
      is_widget = subclass_of require "lapis.eswidget"
      invalid_module_error = "You attempted to compile a module that doesn't extend `lapis.eswidget`. Only ESWidget is supported for compiling to JavaScript"

      if args.file
        widget = require path_to_module args.file
        assert is_widget(widget), invalid_module_error
        print widget\compile_es_module!
      elseif args.module
        widget = require args.module
        assert is_widget(widget), invalid_module_error
        print widget\compile_es_module!
      elseif args.package
        count = 0
        import trim from require "lapis.util"

        for {:file, :widget} in each_widget!
          continue unless types.array_contains(args.package) widget.asset_packages

          js_code = assert widget\compile_es_module!
          count += 1
          print "// #{file} (#{table.concat widget.asset_packages, ", "})"
          print trim js_code
          print!

        if count == 0
          error "You attempted to compile a package that has no matching widgets, aborting (package: #{args.package})"
      else
        error "You called compile_js but did not specify what to compile. Provide one of: --file, --module, or --package"

    when "generate_spec"
      import to_json from require "lapis.util"

      input_to_output = (input_fname) ->
        input_fname\gsub("%.#{search_extension}$", "") .. ".js"

      package_source_target = (package) ->
        join args.source_dir, "#{package}.js"

      package_output_target = (package, suffix=".js") ->
        join args.output_dir, "#{package}#{suffix}"

      -- relative path to move from args.source_dir to the top level directory
      -- eg static/js -> ../..
      source_to_top = do
        if args.source_dir\match "^/"
          error "--source-dir must be a relative path from the top level directory, and not an absolute path"

        if args.source_dir\match("%.%.") or args.source_dir\match("%./")
          error "--source-dir must not use ../ or ./"

        args.source_dir\gsub("[^/]+", "..") -- this may not be very reliable, but should work in simple cases

      esbuild_args = {
        "--target=es6"
        "--log-level=warning"
        "--bundle"
      }

      if args.sourcemap
        table.insert esbuild_args, "--sourcemap"

      esbuild_args = table.concat esbuild_args, " "

      switch args.format
        when "json"
          asset_spec = {
            config: {
              esbuild: args.esbuild_bin
              moonscript: args.moonscript
              source_dir: args.source_dir
              output_dir: args.output_dir
            }
          }

          for {:module_name, :widget, :file} in each_widget!
            asset_spec.widgets or= {}
            asset_spec.widgets[module_name] = {
              path: file
              target: input_to_output file
              name: widget\widget_name!
              packages: widget.asset_packages
              class_list: { widget\widget_class_list! }
            }

            if next widget.asset_packages
              for package in *widget.asset_packages
                asset_spec.packages or= {}

                unless asset_spec.packages[package]
                  asset_spec.packages[package] = {
                    css_target: if types.one_of(args.css_packages or {}) package
                      package_output_target package, ".css"
                    source_target: package_source_target package
                    bundle_target: package_output_target package
                    bundle_min_target: package_output_target package, ".min.js"
                    widgets: {}
                  }

                table.insert asset_spec.packages[package].widgets, module_name

          print to_json asset_spec

        when "tup"
          print "# This file is automatically generated, do not edit"
          print "export LUA_PATH"
          print "export LUA_CPATH"

          if args.esbuild_bin
            print "ESBUILD=#{shell_quote args.esbuild_bin}"

          print!

          -- declare macros used by individual file commands
          print "!compile_js = |> ^ compile_js %f > %o^ lapis-eswidget compile_js #{args.moonscript and "--moonscript" or ""} --file %f > %o |>"
          print [[!join_bundle = |> ^ join bundle %o^ (for file in %f; do echo 'import "]] .. join(source_to_top, "'$file'") .. [[";' | sed 's/\.js//'; done) > %o |>]]

          switch args.minify
            when "both", "none"
              print "!esbuild_bundle = |> ^ esbuild bundle %o^ NODE_PATH=#{shell_quote args.source_dir} $(ESBUILD) #{esbuild_args} %f --outfile=%o |>"

          switch args.minify
            when "both", "only"
              print "!esbuild_bundle_minified = |> ^ esbuild minified bundle %o^ NODE_PATH=#{shell_quote args.source_dir} $(ESBUILD) #{esbuild_args} --minify %f --outfile=%o |>"

          print!

          appended_group = (group_setting, prefix="") ->
            if group_setting and group_setting != ""
              "#{prefix}#{group_setting}"
            else
              ""

          package_files = {}

          -- a tup rule can't put a single output into multiple bins, so we have to list these files manually
          binned_packages = {}
          unbinned_files = {}

          package_dependencies = (package, group_name) ->
            out = {}
            if binned_packages[package]
              table.insert out, "{package_#{package}}"

            if unbinned_files[package]
              for file in *unbinned_files[package]
                table.insert out, file

            if group_name and group_name != ""
              table.insert out, group_name

            table.concat out, " "

          for {:file, :module_name, :widget} in each_widget!
            for package in *widget.asset_packages
              package_files[package] or= {}
              table.insert package_files[package], file
              "{package_#{package}}"

            out_file = input_to_output file

            bin = if #widget.asset_packages == 1
              binned_packages[widget.asset_packages[1]] = true
              " {package_#{widget.asset_packages[1]}}"
            else
              for package in *widget.asset_packages
                unbinned_files[package] or= {}
                table.insert unbinned_files[package], out_file

              nil

            print ": #{file}#{appended_group args.tup_compile_dep_group, " | "} |> !compile_js |> #{out_file}#{bin or ""}"

          packages = [k for k in pairs package_files]
          table.sort packages

          output_with_extras = (package, suffix) ->
            target = package_output_target package, suffix
            local css_target

            extras = {}

            if types.one_of(args.css_packages or {}) package
              css_target = package_output_target package, suffix == ".min.js" and ".min.css" or ".css"
              table.insert extras, css_target

            if args.sourcemap
              table.insert extras, target .. ".map"
              if css_target
                table.insert extras, css_target .. ".map"

            if next extras
              "#{shell_quote target} | #{table.concat ["#{shell_quote e}" for e in *extras], " "}"
            else
              shell_quote target

          for package in *packages
            files = package_files[package]
            table.sort files

            print!
            print "# package: #{package}"
            -- TODO: this intermediate file may be unecessary, we can consider piping the result directly into esbuild
            print ": #{package_dependencies package} |> !join_bundle |> #{shell_quote package_source_target package}"

            package_inputs = "#{shell_quote package_source_target package} | #{package_dependencies package, args.tup_bundle_dep_group}"

            if args.minify == "only"
              print ": #{package_inputs} |> !esbuild_bundle_minified |> #{output_with_extras  package, ".min.js"}"
            else
              print ": #{package_inputs} |> !esbuild_bundle |> #{output_with_extras package} {packages}"

          -- if both minified and regular bundles are created, then do minifucation as separate step
          if args.minify == "both"
            print!
            print "# minifying packages"
            for package in *packages
              print ": #{shell_quote package_source_target package} | {packages} |> !esbuild_bundle_minified |> #{output_with_extras package, ".min.js"}"

        when "makefile"
          print "ESBUILD=#{shell_quote args.esbuild_bin or "esbuild"}"
          print!

          found_widgets = [tuple for tuple in each_widget!]

          package_files = {}
          for {:file, :module_name, :widget} in *found_widgets
            for package in *widget.asset_packages
              package_files[package] or= {}
              table.insert package_files[package], file


          bundle_outputs = {}

          for package in pairs package_files
            table.insert bundle_outputs, package_output_target package
            table.insert bundle_outputs, package_output_target package, ".min.js"

          table.sort bundle_outputs
          print ".PHONY: all clean"
          print "all: #{table.concat bundle_outputs, " "}"
          print!

          all_outputs = {}
          append_output = (out) ->
            table.insert all_outputs, out
            out

          print "# Building modules"
          for {:file, :module_name, :widget} in *found_widgets
            print "#{append_output input_to_output file}: #{file}"
            print "", "lapis-eswidget compile_js #{args.moonscript and "--moonscript" or ""} --file \"$<\" > \"$@\""
            print!


          packages = [k for k in pairs package_files]
          table.sort packages

          for package in *packages
            files = package_files[package]
            print "# Building package: #{package}"
            package_dependencies = [input_to_output file for file in *files]
            print "#{append_output package_source_target package}: #{table.concat package_dependencies, " "}"
            print "", "mkdir -p \"#{args.source_dir}\""
            print "", [[(for file in $^; do echo 'import "]] .. join(source_to_top, "'$$file'") .. [[";' | sed 's/\.js//'; done) > "$@"]]
            print!

            switch args.minify
              when "both", "none"
                bundle_target = append_output package_output_target package

                if args.sourcemap
                  append_output "#{bundle_target}.map"

                print "#{bundle_target}: #{package_source_target package}"
                print "", "mkdir -p \"#{args.output_dir}\""
                print "", "NODE_PATH=#{shell_quote args.source_dir} $(ESBUILD) #{esbuild_args} $< --outfile=$@"
                print!

            switch args.minify
              when "both", "only"
                bundle_target = append_output package_output_target package, ".min.js"

                if args.sourcemap
                  append_output "#{bundle_target}.map"

                print "#{bundle_target}: #{package_source_target package}"
                print "", "mkdir -p \"#{args.output_dir}\""
                print "", "NODE_PATH=#{shell_quote args.source_dir} $(ESBUILD) #{esbuild_args} --minify $< --outfile=$@"
                print!

          print "# Misc rules"
          print "clean:"
          print "", "rm #{table.concat [shell_quote(o) for o in *all_outputs], " "}"


    when "debug"
      Widget = require args.module_name

      print "Config"
      print "=================="
      print "widget name", Widget\widget_name!
      print "packages:", table.concat Widget.asset_packages, ", "
      print "init method:", Widget\es_module_init_function_name!
      print "class names:", table.concat { Widget\widget_class_list!}, ", "

      print!

      -- TODO: do we want this?
      -- print "Asset files"
      -- print "=================="
      -- print "scss:", Widget\get_asset_file "scss"
      -- print "coffee:", Widget\get_asset_file "coffee"

      print!

      print "ES module"
      print "=================="
      print Widget\compile_es_module!
    else
      error "unhandled command: #{args.command}"


_M

