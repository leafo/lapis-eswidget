import types from require "tableshape"
import subclass_of from require "tableshape.moonscript"

import shell_escape, join from require "lapis.cmd.path"

unpack = table.unpack or unpack

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

-- this dumps the arguments as a json string that can be embedded into generated
-- file for reference
dump_args = (args) ->
  import to_json from require "lapis.util"
  out = {}

  tuples = [{k,v} for k,v in pairs args]
  table.sort tuples, (a, b) -> a[1] < b[1]

  out = table.concat ["#{to_json t[1]}: #{to_json t[2]}" for t in *tuples], ", "
  "{#{out}}"

-- Detect if a sidecar CSS file exists for a widget file
-- widget_file_path: "views/login.moon" or "views/login.lua"
-- Returns CSS file path if found, nil otherwise
detect_widget_css = (widget_file_path) ->
  base_path = widget_file_path\gsub("%.moon$", "")\gsub("%.lua$", "")
  css_path = "#{base_path}.css"

  lfs = require "lfs"
  attr = lfs.attributes css_path
  if attr and attr.mode == "file"
    return css_path

  nil

-- Wrap CSS content with widget class for scoping
-- Returns scoped CSS string
scope_css = (css_content, widget_class_name) ->
  ".#{widget_class_name} {\n#{css_content}\n}"

-- Read file contents
read_file = (path) ->
  f = io.open path, "r"
  return nil, "failed to open file: #{path}" unless f
  content = f\read "*a"
  f\close!
  content

-- args should come from parsed argparse result
_M.run = (args) ->
  print = (...) -> _M.print ...
  search_extension = "lua"

  if args.moonscript
    search_extension = "moon"
    require "moonscript"

  -- TODO: this picks up inherted widgets that don't implement es_module
  -- themselves
  is_valid_widget = subclass_of(require "lapis.eswidget") * types.partial {
    es_module: types.string
  }

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

  count_directories = (str) -> #[k for k in str\gmatch "[/\\]"]

  each_widget = ->
    coroutine.wrap ->
      module_files = [file for file in each_module_file unpack args.widget_dirs]
      table.sort module_files, (a, b) ->
        a_count = count_directories(a)
        b_count = count_directories(b)

        if a_count == b_count
          a < b
        else
          a_count < b_count

      for file in *module_files
        module_name = path_to_module file
        widget = require module_name
        continue unless is_valid_widget widget

        unless widget.asset_packages
          _M.print_warning "Widget without @asset_packages"
          continue

        coroutine.yield {
          :file
          module_name: path_to_module file
          :widget
        }

  -- Check if es_module already has CSS imports (for backward compatibility)
  has_css_import = (widget) ->
    es_module = rawget widget, "es_module"
    return false unless es_module
    for line in es_module\gmatch "([^\r\n]+)"
      if line\match "^%s*import.+%.css"
        return true
    false

  -- Determine CSS path for a widget (for JS import)
  -- Returns path to import (relative), or nil if no CSS
  get_css_import_path = (widget, widget_file) ->
    -- Priority 1: inline @css_module (generates .scoped.css)
    if rawget widget, "css_module"
      base = widget_file\gsub("%.moon$", "")\gsub("%.lua$", "")
      return "./#{base}.scoped.css"

    -- Priority 2: explicit @css_file (generates .scoped.css)
    if rawget widget, "css_file"
      base = widget_file\gsub("%.moon$", "")\gsub("%.lua$", "")
      return "./#{base}.scoped.css"

    -- Priority 3: sidecar CSS file (generates .scoped.css)
    -- Only auto-detect if es_module doesn't already have CSS imports (backward compatibility)
    if detect_widget_css(widget_file) and not has_css_import(widget)
      base = widget_file\gsub("%.moon$", "")\gsub("%.lua$", "")
      return "./#{base}.scoped.css"

    nil

  switch args.command
    when "compile_js"
      invalid_module_error = "You attempted to compile a module that doesn't extend `lapis.eswidget`. Only ESWidget is supported for compiling to JavaScript"

      if args.file
        widget = require path_to_module args.file
        assert is_valid_widget(widget), invalid_module_error

        -- Get CSS path and dependencies for this widget
        css_path = get_css_import_path widget, args.file
        css_deps = widget.css_module_dependencies

        print assert widget\compile_es_module css_path, css_deps
      elseif args.module
        widget = require args.module
        assert is_valid_widget(widget), invalid_module_error
        -- Without file path, we can't detect sidecar CSS, but can still use @css_module
        css_path = if rawget widget, "css_module"
          -- Can't generate proper path without file, skip CSS import
          nil
        else
          nil
        css_deps = widget.css_module_dependencies
        print assert widget\compile_es_module css_path, css_deps
      elseif args.package
        count = 0
        import trim from require "lapis.util"

        for {:file, :widget} in each_widget!
          continue unless types.array_contains(args.package) widget.asset_packages

          css_path = get_css_import_path widget, file
          css_deps = widget.css_module_dependencies

          js_code = assert widget\compile_es_module css_path, css_deps
          count += 1
          print "// #{file} (#{table.concat widget.asset_packages, ", "})"
          print trim js_code
          print!

        if count == 0
          error "You attempted to compile a package that has no matching widgets, aborting (package: #{args.package})"
      else
        error "You called compile_js but did not specify what to compile. Provide one of: --file, --module, or --package"

    when "compile_css"
      -- Compile CSS for a widget, wrapping it with the widget class for scoping
      -- Sources: inline @css_module, explicit @css_file, or sidecar CSS file
      invalid_module_error = "You attempted to compile CSS for a module that doesn't extend `lapis.eswidget`"

      get_widget_css = (widget, widget_file) ->
        widget_class_name = widget\widget_class_name!

        -- Priority 1: inline @css_module
        if css_module = rawget widget, "css_module"
          return scope_css css_module, widget_class_name

        -- Priority 2: explicit @css_file
        if css_file = rawget widget, "css_file"
          -- css_file is relative to widget file, resolve it
          base_dir = widget_file\match("^(.*/)")  or ""
          full_css_path = base_dir .. css_file
          css_content, err = read_file full_css_path
          error "Failed to read CSS file #{full_css_path}: #{err}" unless css_content
          return scope_css css_content, widget_class_name

        -- Priority 3: sidecar CSS file (auto-detected)
        if sidecar_css = detect_widget_css widget_file
          css_content, err = read_file sidecar_css
          error "Failed to read sidecar CSS file #{sidecar_css}: #{err}" unless css_content
          return scope_css css_content, widget_class_name

        nil, "Widget has no CSS (no @css_module, @css_file, or sidecar CSS file)"

      ESWidget = require "lapis.eswidget"

      if args.file
        widget = require path_to_module args.file
        assert subclass_of(ESWidget)(widget), invalid_module_error
        css, err = get_widget_css widget, args.file
        if css
          print css
        else
          error err
      elseif args.module
        -- For module, we don't have the file path, so we can only compile @css_module
        widget = require args.module
        assert subclass_of(ESWidget)(widget), invalid_module_error
        css = widget\compile_css_module!
        if css
          print css
        else
          error "Widget has no @css_module (use --file for sidecar CSS support)"
      else
        error "You called compile_css but did not specify what to compile. Provide --file or --module"

    when "generate_spec"
      import to_json from require "lapis.util"

      input_to_output = (input_fname) ->
        input_fname\gsub("%.#{search_extension}$", "") .. ".js"

      -- Generate scoped CSS output path from widget file
      input_to_css_output = (input_fname) ->
        input_fname\gsub("%.#{search_extension}$", "") .. ".scoped.css"

      -- Check if a widget has CSS (any of the three sources)
      -- For sidecar detection, only consider it if es_module doesn't already have CSS imports
      widget_has_css = (widget, widget_file) ->
        if rawget widget, "css_module"
          return true, "inline"
        if rawget widget, "css_file"
          return true, "explicit"
        -- Only auto-detect sidecar if no existing CSS imports (backward compatibility)
        if detect_widget_css(widget_file) and not has_css_import(widget)
          return true, "sidecar"
        false, nil

      -- TODO: this will be removed when intermediate build file is removed for esbuild bundling
      package_source_target = (package) ->
        join args.source_dir, "#{package}.js"

      package_output_target = (package, suffix=".js") ->
        join args.output_dir, "#{package}#{suffix}"

      -- relative path to move from dir to the top level directory
      -- eg static/js -> ../..
      relative_to_top = (path, label) ->
        if path\match "^/"
          error "#{label} must be a relative path from the top level directory, and not an absolute path"

        if path\match("%.%.") or path\match("%./")
          error "#{label} must not use ../ or ./"

        path\gsub("[^/]+", "..") -- this may not be very reliable, but should work in simple cases

      esbuild_args = {
        "--target=es6"
        "--log-level=warning"
        "--bundle"
      }

      if args.sourcemap
        table.insert esbuild_args, "--sourcemap"

      esbuild_args = table.concat esbuild_args, " "

      if args.esbuild_args
        esbuild_args ..= " #{args.esbuild_args}"

      switch args.format
        when "json"
          asset_spec = {
            config: {
              esbuild: args.esbuild_bin
              :esbuild_args
              moonscript: args.moonscript
              source_dir: args.source_dir
              output_dir: args.output_dir
            }
          }

          -- Track packages that have widgets with CSS
          packages_with_css = {}

          for {:module_name, :widget, :file} in each_widget!
            asset_spec.widgets or= {}

            has_css, css_type = widget_has_css widget, file
            widget_info = {
              path: file
              target: input_to_output file
              name: widget\widget_name!
              packages: widget.asset_packages
              class_list: { widget\widget_class_list! }
            }

            -- Add CSS info if widget has CSS
            if has_css
              widget_info.has_css = true
              widget_info.css_type = css_type
              widget_info.css_target = input_to_css_output file

            asset_spec.widgets[module_name] = widget_info

            if next widget.asset_packages
              for package in *widget.asset_packages
                if has_css
                  packages_with_css[package] = true

                asset_spec.packages or= {}

                unless asset_spec.packages[package]
                  asset_spec.packages[package] = {
                    source_target: package_source_target package
                    bundle_target: package_output_target package
                    bundle_min_target: package_output_target package, ".min.js"
                    widgets: {}
                  }

                table.insert asset_spec.packages[package].widgets, module_name

          -- Set CSS targets for packages that have CSS
          for package, pkg_info in pairs asset_spec.packages or {}
            if packages_with_css[package] or types.one_of(args.css_packages or {})(package)
              pkg_info.css_target = package_output_target package, ".css"
              pkg_info.css_min_target = package_output_target package, ".min.css"

          print to_json asset_spec

        when "tup"
          print "# This file is automatically generated, do not edit (lapis-eswidget #{require("lapis.eswidget.version")})"
          import to_json from require "lapis.util"
          print "# #{dump_args args}"
          print "export LUA_PATH"
          print "export LUA_CPATH"

          if args.esbuild_bin
            print "ESBUILD=#{shell_quote args.esbuild_bin}"

          print!

          -- declare macros used by individual file commands
          print "!compile_js = |> ^ compile_js %f > %o^ lapis-eswidget compile_js #{args.moonscript and "--moonscript" or ""} --file %f > %o |>"
          print "!compile_css = |> ^ compile_css %f > %o^ lapis-eswidget compile_css #{args.moonscript and "--moonscript" or ""} --file %f > %o |>"

          separate_minify = false

          -- the build command initialization will store what output options
          -- are supported when listing generated files
          output_args = { }

          -- declare macro for bundling
          unless args.skip_bundle
            switch args.bundle_method
              when "esbuild"
                _esbuild_args = esbuild_args

                if args.esbuild_metafile
                  output_args.esbuild_metafile = true
                  _esbuild_args ..= " --metafile=%O-metafile.json"

                output_args.sourcemap = args.sourcemap
                output_args.css_packages = args.css_packages

                -- dynamically generate a single entry point referencing all modules and pipe it into esbuild
                esbuild_command = table.concat {
                  -- The anonymous module is being executed in the current
                  -- directory, so we just use relative path from root, ./
                  [[(for file in %f; do echo 'import "]] .. join("./", "'$file'") .. [[";'; done)]]
                  "NODE_PATH=#{shell_quote args.source_dir} $(ESBUILD) #{_esbuild_args} --outfile=%o"
                }, " | "

                switch args.minify
                  when "both", "none"
                    print "!bundle_js = |> ^ esbuild bundle %o^ #{esbuild_command} |>"

                switch args.minify
                  when "both", "only"
                    separate_minify = true
                    print "!bundle_js_minified = |> ^ esbuild minified bundle %o^ #{esbuild_command} --minify |>"

              when "module"
                to_root = relative_to_top args.output_dir, "--output-dir"
                print [[!bundle_js = |> ^ join module %o^ (for file in %f; do echo 'import "]] .. join(to_root, "'$file'") .. [[";' | sed 's/\.js//'; done) > %o |>]]
              when "concat"
                print [[!bundle_js = |> ^ join %o^ cat %f > %o |>]]
              else
                error "Expected to have bundle type but have none"

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

          generate_package_inputs = (package, ...) ->
            out = {}
            if binned_packages[package]
              table.insert out, "{package_#{package}}"

            if unbinned_files[package]
              for file in *unbinned_files[package]
                table.insert out, file

            extra_inputs = {...}
            have_pipe = false

            for extra in *extra_inputs
              continue unless extra
              continue if extra == ""

              unless have_pipe
                table.insert out, "|"
                have_pipe = true

              table.insert out, extra

            table.concat out, " "

          -- Track packages that have widgets with CSS for auto-detection
          packages_with_css = {}

          -- Generate CSS rules first (CSS must be compiled before JS imports it)
          css_rules = {}
          for {:file, :module_name, :widget} in each_widget!
            has_css, css_type = widget_has_css widget, file
            if has_css
              css_out_file = input_to_css_output file
              -- Track that this package has CSS
              for package in *widget.asset_packages
                packages_with_css[package] = true
              -- CSS rule: compile CSS from widget file (handles sidecar, inline, or explicit)
              table.insert css_rules, ": #{file}#{appended_group args.tup_compile_dep_group, " | "} |> !compile_css |> #{css_out_file}"

          if next css_rules
            table.sort css_rules
            print "# CSS compilation"
            for rule in *css_rules
              print rule
            print!

          -- Auto-detect CSS packages if not explicitly specified
          effective_css_packages = args.css_packages or {}
          if next packages_with_css
            -- Merge auto-detected packages with explicit ones
            for package in pairs packages_with_css
              found = false
              for existing in *effective_css_packages
                if existing == package
                  found = true
                  break
              unless found
                table.insert effective_css_packages, package

          -- Update output_args with effective CSS packages
          output_args.css_packages = if next(effective_css_packages) then effective_css_packages else nil

          rules = for {:file, :module_name, :widget} in each_widget!
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

            ": #{file}#{appended_group args.tup_compile_dep_group, " | "} |> !compile_js |> #{out_file}#{appended_group args.tup_compile_out_group, " "}#{bin or ""}"

          print "# JS compilation"
          table.sort rules
          for rule in *rules
            print rule

          packages = [k for k in pairs package_files]
          table.sort packages

          output_with_extras = (package, suffix) ->
            target = package_output_target package, suffix
            local css_target

            extras = {}

            if types.one_of(output_args.css_packages or {}) package
              css_target = package_output_target package, suffix == ".min.js" and ".min.css" or ".css"
              table.insert extras, css_target

            if args.sourcemap
              if output_args.sourcemap
                table.insert extras, target .. ".map"
                if css_target
                  table.insert extras, css_target .. ".map"
              else
                _M.print_warning "[#{package}] You used --sourcemap on a bundle method that does not support it (#{args.bundle_method})"

            if args.esbuild_metafile
              if output_args.esbuild_metafile
                table.insert extras, "%O-metafile.json"
              else
                _M.print_warning "[#{package}] You used --esbuild-metafile on a bundle method that does not support it (#{args.bundle_method})"

            if next extras
              "#{shell_quote target} | #{table.concat ["#{shell_quote e}" for e in *extras], " "}"
            else
              shell_quote target

          unless args.skip_bundle
            for package in *packages
              files = package_files[package]
              table.sort files

              print!
              print "# package: #{package}"

              out_group = if args.tup_bundle_out_group
                " #{args.tup_bundle_out_group}"
              else
                ""

              unless args.skip_bundle
                package_inputs = generate_package_inputs package, args.tup_bundle_dep_group

                if args.minify == "only"
                  unless separate_minify
                    error "The --bundle-method you chose does not support minification"

                  print ": #{package_inputs} |> !bundle_js_minified |> #{output_with_extras  package, ".min.js"}#{out_group}"
                else
                  print ": #{package_inputs} |> !bundle_js |> #{output_with_extras package}#{out_group} {packages}"

            -- if both minified and regular bundles are created, then do minification as separate step
            if args.minify == "both" and next(packages) and separate_minify
              print!
              print "# minifying packages"
              for package in *packages
                package_inputs = generate_package_inputs package, args.tup_bundle_dep_group, "{packages}"
                print ": #{package_inputs} |> !bundle_js_minified |> #{output_with_extras package, ".min.js"}"

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
          unless next found_widgets
            print "# Warning: No modules found"
            print!

          for {:file, :module_name, :widget} in *found_widgets
            print "#{append_output input_to_output file}: #{file}"
            print "", "lapis-eswidget compile_js #{args.moonscript and "--moonscript" or ""} --file \"$<\" > \"$@\""
            print!

          packages = [k for k in pairs package_files]
          table.sort packages

          to_root = relative_to_top args.source_dir, "--source-dir"

          for package in *packages
            files = package_files[package]
            print "# Building package: #{package}"
            package_dependencies = [input_to_output file for file in *files]
            print "#{append_output package_source_target package}: #{table.concat package_dependencies, " "}"
            print "", "mkdir -p #{shell_quote args.source_dir}"
            print "", [[(for file in $^; do echo 'import "]] .. join(to_root, "'$$file'") .. [[";' | sed 's/\.js//'; done) > "$@"]]
            print!

            has_css = types.one_of(args.css_packages or {}) package

            unless args.skip_bundle
              -- unminified output
              switch args.minify
                when "both", "none"
                  command_args = esbuild_args
                  if args.esbuild_metafile
                    metafile_output = package_output_target package, "-metafile.json"
                    append_output metafile_output
                    command_args ..= " --metafile=#{shell_quote metafile_output}"

                  bundle_target = append_output package_output_target package

                  if has_css
                    append_output package_output_target package, ".css"

                  if args.sourcemap
                    append_output "#{bundle_target}.map"

                    if has_css
                      append_output package_output_target package, ".css.map"

                  print "#{bundle_target}: #{package_source_target package}"
                  print "", "NODE_PATH=#{shell_quote args.source_dir} $(ESBUILD) #{command_args} \"$<\" --outfile=\"$@\""
                  print!

              -- minified output
              switch args.minify
                when "both", "only"
                  command_args = esbuild_args

                  if args.esbuild_metafile
                    metafile_output = package_output_target package, ".min-metafile.json"
                    append_output metafile_output
                    command_args ..= " --metafile=#{shell_quote metafile_output}"

                  bundle_target = append_output package_output_target package, ".min.js"

                  if has_css
                    append_output package_output_target package, ".min.css"

                  if args.sourcemap
                    append_output "#{bundle_target}.map"

                    if has_css
                      append_output package_output_target package, ".min.css.map"

                  print "#{bundle_target}: #{package_source_target package}"
                  print "", "NODE_PATH=#{shell_quote args.source_dir} $(ESBUILD) #{command_args} --minify \"$<\" --outfile=\"$@\""
                  print!

          print "# Misc rules"
          print "clean:"
          if next all_outputs
            print "", "rm #{table.concat [shell_quote(o) for o in *all_outputs], " "}"


    when "debug"
      Widget = require args.module_name

      assert subclass_of(require "lapis.eswidget")(Widget),
        "You attempted to load a module that doesn't extend `lapis.eswidget`"

      print "Config"
      print "=================="
      print "widget name", Widget\widget_name!
      print "packages:", table.concat Widget.asset_packages, ", "
      print "init method:", Widget\es_module_init_function_name!
      print "class names:", table.concat { Widget\widget_class_list!}, ", "
      print!

      -- CSS info
      print "CSS"
      print "=================="
      if rawget Widget, "css_module"
        print "css_module:", "(inline CSS defined)"
      elseif rawget Widget, "css_file"
        print "css_file:", Widget.css_file
      else
        print "(no CSS defined)"

      css_deps = Widget.css_module_dependencies
      if css_deps and next css_deps
        print "css dependencies:", table.concat css_deps, ", "
      print!

      -- TODO: do we want this?
      -- print "Asset files"
      -- print "=================="
      -- print "scss:", Widget\get_asset_file "scss"
      -- print "coffee:", Widget\get_asset_file "coffee"

      print!
      print "Dependencies"
      print "=================="
      deps = Widget.es_module_dependencies
      if deps and next deps
        if args.recursive
          visited = {}

          print_dep_tree = (dep, indent="", is_last=true) ->
            connector = if indent == ""
              ""
            elseif is_last
              "└ "
            else
              "├ "

            print "#{indent}#{connector}#{dep}"

            return if visited[dep]
            visited[dep] = true

            ok, mod = pcall require, dep
            unless ok and type(mod) == "table"
              branch_indent = if is_last then "    " else "│   "
              print "#{indent}#{branch_indent}(failed to load: #{mod})"
              return

            subdeps = mod.es_module_dependencies
            return unless subdeps and next subdeps

            next_indent = indent .. (if is_last then "  " else "│ ")
            for i, subdep in ipairs subdeps
              print_dep_tree subdep, next_indent, i == #subdeps

          for i, dep in ipairs deps
            print_dep_tree dep, "", i == #deps
        else
          for dep in *deps
            print dep
      else
        print "(none)"

      print!
      print "ES module"
      print "=================="
      print Widget\compile_es_module!

    else
      error "unhandled command: #{args.command}"


_M
