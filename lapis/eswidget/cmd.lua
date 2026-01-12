local types
types = require("tableshape").types
local subclass_of
subclass_of = require("tableshape.moonscript").subclass_of
local shell_escape, join
do
  local _obj_0 = require("lapis.cmd.path")
  shell_escape, join = _obj_0.shell_escape, _obj_0.join
end
local unpack = table.unpack or unpack
local _M = {
  print = print,
  print_warning = function(msg)
    io.stderr:write(msg)
    return io.stderr:write("\n")
  end
}
local shell_quote
shell_quote = function(str)
  if str:match("'") then
    return "'" .. tostring(shell_escape(str)) .. "'"
  else
    return str
  end
end
local dump_args
dump_args = function(args)
  local to_json
  to_json = require("lapis.util").to_json
  local out = { }
  local tuples
  do
    local _accum_0 = { }
    local _len_0 = 1
    for k, v in pairs(args) do
      _accum_0[_len_0] = {
        k,
        v
      }
      _len_0 = _len_0 + 1
    end
    tuples = _accum_0
  end
  table.sort(tuples, function(a, b)
    return a[1] < b[1]
  end)
  out = table.concat((function()
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #tuples do
      local t = tuples[_index_0]
      _accum_0[_len_0] = tostring(to_json(t[1])) .. ": " .. tostring(to_json(t[2]))
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)(), ", ")
  return "{" .. tostring(out) .. "}"
end
local detect_widget_css
detect_widget_css = function(widget_file_path)
  local base_path = widget_file_path:gsub("%.moon$", ""):gsub("%.lua$", "")
  local css_path = tostring(base_path) .. ".css"
  local lfs = require("lfs")
  local attr = lfs.attributes(css_path)
  if attr and attr.mode == "file" then
    return css_path
  end
  return nil
end
local scope_css
scope_css = function(css_content, widget_class_name)
  return "." .. tostring(widget_class_name) .. " {\n" .. tostring(css_content) .. "\n}"
end
local read_file
read_file = function(path)
  local f = io.open(path, "r")
  if not (f) then
    return nil, "failed to open file: " .. tostring(path)
  end
  local content = f:read("*a")
  f:close()
  return content
end
_M.run = function(args)
  local print
  print = function(...)
    return _M.print(...)
  end
  local search_extension = "lua"
  if args.moonscript then
    search_extension = "moon"
    require("moonscript")
  end
  local is_valid_widget = subclass_of(require("lapis.eswidget")) * types.partial({
    es_module = types.string
  })
  local path_to_module
  path_to_module = function(path)
    return (path:gsub("%." .. tostring(search_extension) .. "$", ""):gsub("/+", "."))
  end
  local each_module_file
  do
    local scan_prefix
    scan_prefix = function(...)
      local prefixes = {
        ...
      }
      local lfs = require("lfs")
      for _index_0 = 1, #prefixes do
        local prefix = prefixes[_index_0]
        local subdirs = { }
        for file in lfs.dir(prefix) do
          local _continue_0 = false
          repeat
            if file == "." then
              _continue_0 = true
              break
            end
            if file == ".." then
              _continue_0 = true
              break
            end
            local full_path = tostring(prefix) .. "/" .. tostring(file)
            local attr = lfs.attributes(full_path)
            if not (attr) then
              _continue_0 = true
              break
            end
            if attr.mode == "directory" then
              table.insert(subdirs, full_path)
            else
              if full_path:match("%." .. tostring(search_extension) .. "$") then
                coroutine.yield(full_path)
              end
            end
            _continue_0 = true
          until true
          if not _continue_0 then
            break
          end
        end
        scan_prefix(unpack(subdirs))
      end
    end
    each_module_file = function(...)
      local prefixes = {
        ...
      }
      return coroutine.wrap(function()
        return scan_prefix(unpack(prefixes))
      end)
    end
  end
  local count_directories
  count_directories = function(str)
    return #(function()
      local _accum_0 = { }
      local _len_0 = 1
      for k in str:gmatch("[/\\]") do
        _accum_0[_len_0] = k
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end)()
  end
  local each_widget
  each_widget = function()
    return coroutine.wrap(function()
      local module_files
      do
        local _accum_0 = { }
        local _len_0 = 1
        for file in each_module_file(unpack(args.widget_dirs)) do
          _accum_0[_len_0] = file
          _len_0 = _len_0 + 1
        end
        module_files = _accum_0
      end
      table.sort(module_files, function(a, b)
        local a_count = count_directories(a)
        local b_count = count_directories(b)
        if a_count == b_count then
          return a < b
        else
          return a_count < b_count
        end
      end)
      for _index_0 = 1, #module_files do
        local _continue_0 = false
        repeat
          local file = module_files[_index_0]
          local module_name = path_to_module(file)
          local widget = require(module_name)
          if not (is_valid_widget(widget)) then
            _continue_0 = true
            break
          end
          if not (widget.asset_packages) then
            _M.print_warning("Widget without @asset_packages")
            _continue_0 = true
            break
          end
          coroutine.yield({
            file = file,
            module_name = path_to_module(file),
            widget = widget
          })
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
    end)
  end
  local has_css_import
  has_css_import = function(widget)
    local es_module = rawget(widget, "es_module")
    if not (es_module) then
      return false
    end
    for line in es_module:gmatch("([^\r\n]+)") do
      if line:match("^%s*import.+%.css") then
        return true
      end
    end
    return false
  end
  local get_css_import_path
  get_css_import_path = function(widget, widget_file)
    if rawget(widget, "css_module") then
      local base = widget_file:gsub("%.moon$", ""):gsub("%.lua$", "")
      return "./" .. tostring(base) .. ".scoped.css"
    end
    if rawget(widget, "css_file") then
      local base = widget_file:gsub("%.moon$", ""):gsub("%.lua$", "")
      return "./" .. tostring(base) .. ".scoped.css"
    end
    if detect_widget_css(widget_file) and not has_css_import(widget) then
      local base = widget_file:gsub("%.moon$", ""):gsub("%.lua$", "")
      return "./" .. tostring(base) .. ".scoped.css"
    end
    return nil
  end
  local _exp_0 = args.command
  if "compile_js" == _exp_0 then
    local invalid_module_error = "You attempted to compile a module that doesn't extend `lapis.eswidget`. Only ESWidget is supported for compiling to JavaScript"
    if args.file then
      local widget = require(path_to_module(args.file))
      assert(is_valid_widget(widget), invalid_module_error)
      local css_path = get_css_import_path(widget, args.file)
      local css_deps = widget.css_module_dependencies
      return print(assert(widget:compile_es_module(css_path, css_deps)))
    elseif args.module then
      local widget = require(args.module)
      assert(is_valid_widget(widget), invalid_module_error)
      local css_path
      if rawget(widget, "css_module") then
        css_path = nil
      else
        css_path = nil
      end
      local css_deps = widget.css_module_dependencies
      return print(assert(widget:compile_es_module(css_path, css_deps)))
    elseif args.package then
      local count = 0
      local trim
      trim = require("lapis.util").trim
      for _des_0 in each_widget() do
        local _continue_0 = false
        repeat
          local file, widget
          file, widget = _des_0.file, _des_0.widget
          if not (types.array_contains(args.package)(widget.asset_packages)) then
            _continue_0 = true
            break
          end
          local css_path = get_css_import_path(widget, file)
          local css_deps = widget.css_module_dependencies
          local js_code = assert(widget:compile_es_module(css_path, css_deps))
          count = count + 1
          print("// " .. tostring(file) .. " (" .. tostring(table.concat(widget.asset_packages, ", ")) .. ")")
          print(trim(js_code))
          print()
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      if count == 0 then
        return error("You attempted to compile a package that has no matching widgets, aborting (package: " .. tostring(args.package) .. ")")
      end
    else
      return error("You called compile_js but did not specify what to compile. Provide one of: --file, --module, or --package")
    end
  elseif "compile_css" == _exp_0 then
    local invalid_module_error = "You attempted to compile CSS for a module that doesn't extend `lapis.eswidget`"
    local get_widget_css
    get_widget_css = function(widget, widget_file)
      local widget_class_name = widget:widget_class_name()
      do
        local css_module = rawget(widget, "css_module")
        if css_module then
          return scope_css(css_module, widget_class_name)
        end
      end
      do
        local css_file = rawget(widget, "css_file")
        if css_file then
          local base_dir = widget_file:match("^(.*/)") or ""
          local full_css_path = base_dir .. css_file
          local css_content, err = read_file(full_css_path)
          if not (css_content) then
            error("Failed to read CSS file " .. tostring(full_css_path) .. ": " .. tostring(err))
          end
          return scope_css(css_content, widget_class_name)
        end
      end
      do
        local sidecar_css = detect_widget_css(widget_file)
        if sidecar_css then
          local css_content, err = read_file(sidecar_css)
          if not (css_content) then
            error("Failed to read sidecar CSS file " .. tostring(sidecar_css) .. ": " .. tostring(err))
          end
          return scope_css(css_content, widget_class_name)
        end
      end
      return nil, "Widget has no CSS (no @css_module, @css_file, or sidecar CSS file)"
    end
    local ESWidget = require("lapis.eswidget")
    if args.file then
      local widget = require(path_to_module(args.file))
      assert(subclass_of(ESWidget)(widget), invalid_module_error)
      local css, err = get_widget_css(widget, args.file)
      if css then
        return print(css)
      else
        return error(err)
      end
    elseif args.module then
      local widget = require(args.module)
      assert(subclass_of(ESWidget)(widget), invalid_module_error)
      local css = widget:compile_css_module()
      if css then
        return print(css)
      else
        return error("Widget has no @css_module (use --file for sidecar CSS support)")
      end
    else
      return error("You called compile_css but did not specify what to compile. Provide --file or --module")
    end
  elseif "generate_spec" == _exp_0 then
    local to_json
    to_json = require("lapis.util").to_json
    local input_to_output
    input_to_output = function(input_fname)
      return input_fname:gsub("%." .. tostring(search_extension) .. "$", "") .. ".js"
    end
    local input_to_css_output
    input_to_css_output = function(input_fname)
      return input_fname:gsub("%." .. tostring(search_extension) .. "$", "") .. ".scoped.css"
    end
    local widget_has_css
    widget_has_css = function(widget, widget_file)
      if rawget(widget, "css_module") then
        return true, "inline"
      end
      if rawget(widget, "css_file") then
        return true, "explicit"
      end
      if detect_widget_css(widget_file) and not has_css_import(widget) then
        return true, "sidecar"
      end
      return false, nil
    end
    local package_source_target
    package_source_target = function(package)
      return join(args.source_dir, tostring(package) .. ".js")
    end
    local package_output_target
    package_output_target = function(package, suffix)
      if suffix == nil then
        suffix = ".js"
      end
      return join(args.output_dir, tostring(package) .. tostring(suffix))
    end
    local relative_to_top
    relative_to_top = function(path, label)
      if path:match("^/") then
        error(tostring(label) .. " must be a relative path from the top level directory, and not an absolute path")
      end
      if path:match("%.%.") or path:match("%./") then
        error(tostring(label) .. " must not use ../ or ./")
      end
      return path:gsub("[^/]+", "..")
    end
    local esbuild_args = {
      "--target=es6",
      "--log-level=warning",
      "--bundle"
    }
    if args.sourcemap then
      table.insert(esbuild_args, "--sourcemap")
    end
    esbuild_args = table.concat(esbuild_args, " ")
    if args.esbuild_args then
      esbuild_args = esbuild_args .. " " .. tostring(args.esbuild_args)
    end
    local _exp_1 = args.format
    if "json" == _exp_1 then
      local asset_spec = {
        config = {
          esbuild = args.esbuild_bin,
          esbuild_args = esbuild_args,
          moonscript = args.moonscript,
          source_dir = args.source_dir,
          output_dir = args.output_dir
        }
      }
      local packages_with_css = { }
      for _des_0 in each_widget() do
        local module_name, widget, file
        module_name, widget, file = _des_0.module_name, _des_0.widget, _des_0.file
        asset_spec.widgets = asset_spec.widgets or { }
        local has_css, css_type = widget_has_css(widget, file)
        local widget_info = {
          path = file,
          target = input_to_output(file),
          name = widget:widget_name(),
          packages = widget.asset_packages,
          class_list = {
            widget:widget_class_list()
          }
        }
        if has_css then
          widget_info.has_css = true
          widget_info.css_type = css_type
          widget_info.css_target = input_to_css_output(file)
        end
        asset_spec.widgets[module_name] = widget_info
        if next(widget.asset_packages) then
          local _list_0 = widget.asset_packages
          for _index_0 = 1, #_list_0 do
            local package = _list_0[_index_0]
            if has_css then
              packages_with_css[package] = true
            end
            asset_spec.packages = asset_spec.packages or { }
            if not (asset_spec.packages[package]) then
              asset_spec.packages[package] = {
                source_target = package_source_target(package),
                bundle_target = package_output_target(package),
                bundle_min_target = package_output_target(package, ".min.js"),
                widgets = { }
              }
            end
            table.insert(asset_spec.packages[package].widgets, module_name)
          end
        end
      end
      for package, pkg_info in pairs(asset_spec.packages or { }) do
        if packages_with_css[package] or types.one_of(args.css_packages or { })(package) then
          pkg_info.css_target = package_output_target(package, ".css")
          pkg_info.css_min_target = package_output_target(package, ".min.css")
        end
      end
      return print(to_json(asset_spec))
    elseif "tup" == _exp_1 then
      print("# This file is automatically generated, do not edit (lapis-eswidget " .. tostring(require("lapis.eswidget.version")) .. ")")
      to_json = require("lapis.util").to_json
      print("# " .. tostring(dump_args(args)))
      print("export LUA_PATH")
      print("export LUA_CPATH")
      if args.esbuild_bin then
        print("ESBUILD=" .. tostring(shell_quote(args.esbuild_bin)))
      end
      print()
      print("!compile_js = |> ^ compile_js %f > %o^ lapis-eswidget compile_js " .. tostring(args.moonscript and "--moonscript" or "") .. " --file %f > %o |>")
      print("!compile_css = |> ^ compile_css %f > %o^ lapis-eswidget compile_css " .. tostring(args.moonscript and "--moonscript" or "") .. " --file %f > %o |>")
      local separate_minify = false
      local output_args = { }
      if not (args.skip_bundle) then
        local _exp_2 = args.bundle_method
        if "esbuild" == _exp_2 then
          local _esbuild_args = esbuild_args
          if args.esbuild_metafile then
            output_args.esbuild_metafile = true
            _esbuild_args = _esbuild_args .. " --metafile=%O-metafile.json"
          end
          output_args.sourcemap = args.sourcemap
          output_args.css_packages = args.css_packages
          local esbuild_command = table.concat({
            [[(for file in %f; do echo 'import "]] .. join("./", "'$file'") .. [[";'; done)]],
            "NODE_PATH=" .. tostring(shell_quote(args.source_dir)) .. " $(ESBUILD) " .. tostring(_esbuild_args) .. " --outfile=%o"
          }, " | ")
          local _exp_3 = args.minify
          if "both" == _exp_3 or "none" == _exp_3 then
            print("!bundle_js = |> ^ esbuild bundle %o^ " .. tostring(esbuild_command) .. " |>")
          end
          local _exp_4 = args.minify
          if "both" == _exp_4 or "only" == _exp_4 then
            separate_minify = true
            print("!bundle_js_minified = |> ^ esbuild minified bundle %o^ " .. tostring(esbuild_command) .. " --minify |>")
          end
        elseif "module" == _exp_2 then
          local to_root = relative_to_top(args.output_dir, "--output-dir")
          print([[!bundle_js = |> ^ join module %o^ (for file in %f; do echo 'import "]] .. join(to_root, "'$file'") .. [[";' | sed 's/\.js//'; done) > %o |>]])
        elseif "concat" == _exp_2 then
          print([[!bundle_js = |> ^ join %o^ cat %f > %o |>]])
        else
          error("Expected to have bundle type but have none")
        end
        print()
      end
      local appended_group
      appended_group = function(group_setting, prefix)
        if prefix == nil then
          prefix = ""
        end
        if group_setting and group_setting ~= "" then
          return tostring(prefix) .. tostring(group_setting)
        else
          return ""
        end
      end
      local package_files = { }
      local binned_packages = { }
      local unbinned_files = { }
      local generate_package_inputs
      generate_package_inputs = function(package, ...)
        local out = { }
        if binned_packages[package] then
          table.insert(out, "{package_" .. tostring(package) .. "}")
        end
        if unbinned_files[package] then
          local _list_0 = unbinned_files[package]
          for _index_0 = 1, #_list_0 do
            local file = _list_0[_index_0]
            table.insert(out, file)
          end
        end
        local extra_inputs = {
          ...
        }
        local have_pipe = false
        for _index_0 = 1, #extra_inputs do
          local _continue_0 = false
          repeat
            local extra = extra_inputs[_index_0]
            if not (extra) then
              _continue_0 = true
              break
            end
            if extra == "" then
              _continue_0 = true
              break
            end
            if not (have_pipe) then
              table.insert(out, "|")
              have_pipe = true
            end
            table.insert(out, extra)
            _continue_0 = true
          until true
          if not _continue_0 then
            break
          end
        end
        return table.concat(out, " ")
      end
      local packages_with_css = { }
      local css_rules = { }
      for _des_0 in each_widget() do
        local file, module_name, widget
        file, module_name, widget = _des_0.file, _des_0.module_name, _des_0.widget
        local has_css, css_type = widget_has_css(widget, file)
        if has_css then
          local css_out_file = input_to_css_output(file)
          local _list_0 = widget.asset_packages
          for _index_0 = 1, #_list_0 do
            local package = _list_0[_index_0]
            packages_with_css[package] = true
          end
          table.insert(css_rules, ": " .. tostring(file) .. tostring(appended_group(args.tup_compile_dep_group, " | ")) .. " |> !compile_css |> " .. tostring(css_out_file))
        end
      end
      if next(css_rules) then
        table.sort(css_rules)
        print("# CSS compilation")
        for _index_0 = 1, #css_rules do
          local rule = css_rules[_index_0]
          print(rule)
        end
        print()
      end
      local effective_css_packages = args.css_packages or { }
      if next(packages_with_css) then
        for package in pairs(packages_with_css) do
          local found = false
          for _index_0 = 1, #effective_css_packages do
            local existing = effective_css_packages[_index_0]
            if existing == package then
              found = true
              break
            end
          end
          if not (found) then
            table.insert(effective_css_packages, package)
          end
        end
      end
      if next(effective_css_packages) then
        output_args.css_packages = effective_css_packages
      else
        output_args.css_packages = nil
      end
      local rules
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _des_0 in each_widget() do
          local file, module_name, widget
          file, module_name, widget = _des_0.file, _des_0.module_name, _des_0.widget
          local _list_0 = widget.asset_packages
          for _index_0 = 1, #_list_0 do
            local package = _list_0[_index_0]
            local _update_0 = package
            package_files[_update_0] = package_files[_update_0] or { }
            table.insert(package_files[package], file)
            local _ = "{package_" .. tostring(package) .. "}"
          end
          local out_file = input_to_output(file)
          local bin
          if #widget.asset_packages == 1 then
            binned_packages[widget.asset_packages[1]] = true
            bin = " {package_" .. tostring(widget.asset_packages[1]) .. "}"
          else
            local _list_1 = widget.asset_packages
            for _index_0 = 1, #_list_1 do
              local package = _list_1[_index_0]
              local _update_0 = package
              unbinned_files[_update_0] = unbinned_files[_update_0] or { }
              table.insert(unbinned_files[package], out_file)
            end
            bin = nil
          end
          local _value_0 = ": " .. tostring(file) .. tostring(appended_group(args.tup_compile_dep_group, " | ")) .. " |> !compile_js |> " .. tostring(out_file) .. tostring(appended_group(args.tup_compile_out_group, " ")) .. tostring(bin or "")
          _accum_0[_len_0] = _value_0
          _len_0 = _len_0 + 1
        end
        rules = _accum_0
      end
      print("# JS compilation")
      table.sort(rules)
      for _index_0 = 1, #rules do
        local rule = rules[_index_0]
        print(rule)
      end
      local packages
      do
        local _accum_0 = { }
        local _len_0 = 1
        for k in pairs(package_files) do
          _accum_0[_len_0] = k
          _len_0 = _len_0 + 1
        end
        packages = _accum_0
      end
      table.sort(packages)
      local output_with_extras
      output_with_extras = function(package, suffix)
        local target = package_output_target(package, suffix)
        local css_target
        local extras = { }
        if types.one_of(output_args.css_packages or { })(package) then
          css_target = package_output_target(package, suffix == ".min.js" and ".min.css" or ".css")
          table.insert(extras, css_target)
        end
        if args.sourcemap then
          if output_args.sourcemap then
            table.insert(extras, target .. ".map")
            if css_target then
              table.insert(extras, css_target .. ".map")
            end
          else
            _M.print_warning("[" .. tostring(package) .. "] You used --sourcemap on a bundle method that does not support it (" .. tostring(args.bundle_method) .. ")")
          end
        end
        if args.esbuild_metafile then
          if output_args.esbuild_metafile then
            table.insert(extras, "%O-metafile.json")
          else
            _M.print_warning("[" .. tostring(package) .. "] You used --esbuild-metafile on a bundle method that does not support it (" .. tostring(args.bundle_method) .. ")")
          end
        end
        if next(extras) then
          return tostring(shell_quote(target)) .. " | " .. tostring(table.concat((function()
            local _accum_0 = { }
            local _len_0 = 1
            for _index_0 = 1, #extras do
              local e = extras[_index_0]
              _accum_0[_len_0] = tostring(shell_quote(e))
              _len_0 = _len_0 + 1
            end
            return _accum_0
          end)(), " "))
        else
          return shell_quote(target)
        end
      end
      if not (args.skip_bundle) then
        for _index_0 = 1, #packages do
          local package = packages[_index_0]
          local files = package_files[package]
          table.sort(files)
          print()
          print("# package: " .. tostring(package))
          local out_group
          if args.tup_bundle_out_group then
            out_group = " " .. tostring(args.tup_bundle_out_group)
          else
            out_group = ""
          end
          if not (args.skip_bundle) then
            local package_inputs = generate_package_inputs(package, args.tup_bundle_dep_group)
            if args.minify == "only" then
              if not (separate_minify) then
                error("The --bundle-method you chose does not support minification")
              end
              print(": " .. tostring(package_inputs) .. " |> !bundle_js_minified |> " .. tostring(output_with_extras(package, ".min.js")) .. tostring(out_group))
            else
              print(": " .. tostring(package_inputs) .. " |> !bundle_js |> " .. tostring(output_with_extras(package)) .. tostring(out_group) .. " {packages}")
            end
          end
        end
        if args.minify == "both" and next(packages) and separate_minify then
          print()
          print("# minifying packages")
          for _index_0 = 1, #packages do
            local package = packages[_index_0]
            local package_inputs = generate_package_inputs(package, args.tup_bundle_dep_group, "{packages}")
            print(": " .. tostring(package_inputs) .. " |> !bundle_js_minified |> " .. tostring(output_with_extras(package, ".min.js")))
          end
        end
      end
    elseif "makefile" == _exp_1 then
      print("ESBUILD=" .. tostring(shell_quote(args.esbuild_bin or "esbuild")))
      print()
      local found_widgets
      do
        local _accum_0 = { }
        local _len_0 = 1
        for tuple in each_widget() do
          _accum_0[_len_0] = tuple
          _len_0 = _len_0 + 1
        end
        found_widgets = _accum_0
      end
      local package_files = { }
      for _index_0 = 1, #found_widgets do
        local _des_0 = found_widgets[_index_0]
        local file, module_name, widget
        file, module_name, widget = _des_0.file, _des_0.module_name, _des_0.widget
        local _list_0 = widget.asset_packages
        for _index_1 = 1, #_list_0 do
          local package = _list_0[_index_1]
          local _update_0 = package
          package_files[_update_0] = package_files[_update_0] or { }
          table.insert(package_files[package], file)
        end
      end
      local bundle_outputs = { }
      for package in pairs(package_files) do
        table.insert(bundle_outputs, package_output_target(package))
        table.insert(bundle_outputs, package_output_target(package, ".min.js"))
      end
      table.sort(bundle_outputs)
      print(".PHONY: all clean")
      print("all: " .. tostring(table.concat(bundle_outputs, " ")))
      print()
      local all_outputs = { }
      local append_output
      append_output = function(out)
        table.insert(all_outputs, out)
        return out
      end
      print("# Building modules")
      if not (next(found_widgets)) then
        print("# Warning: No modules found")
        print()
      end
      for _index_0 = 1, #found_widgets do
        local _des_0 = found_widgets[_index_0]
        local file, module_name, widget
        file, module_name, widget = _des_0.file, _des_0.module_name, _des_0.widget
        print(tostring(append_output(input_to_output(file))) .. ": " .. tostring(file))
        print("", "lapis-eswidget compile_js " .. tostring(args.moonscript and "--moonscript" or "") .. " --file \"$<\" > \"$@\"")
        print()
      end
      local packages
      do
        local _accum_0 = { }
        local _len_0 = 1
        for k in pairs(package_files) do
          _accum_0[_len_0] = k
          _len_0 = _len_0 + 1
        end
        packages = _accum_0
      end
      table.sort(packages)
      local to_root = relative_to_top(args.source_dir, "--source-dir")
      for _index_0 = 1, #packages do
        local package = packages[_index_0]
        local files = package_files[package]
        print("# Building package: " .. tostring(package))
        local package_dependencies
        do
          local _accum_0 = { }
          local _len_0 = 1
          for _index_1 = 1, #files do
            local file = files[_index_1]
            _accum_0[_len_0] = input_to_output(file)
            _len_0 = _len_0 + 1
          end
          package_dependencies = _accum_0
        end
        print(tostring(append_output(package_source_target(package))) .. ": " .. tostring(table.concat(package_dependencies, " ")))
        print("", "mkdir -p " .. tostring(shell_quote(args.source_dir)))
        print("", [[(for file in $^; do echo 'import "]] .. join(to_root, "'$$file'") .. [[";' | sed 's/\.js//'; done) > "$@"]])
        print()
        local has_css = types.one_of(args.css_packages or { })(package)
        if not (args.skip_bundle) then
          local _exp_2 = args.minify
          if "both" == _exp_2 or "none" == _exp_2 then
            local command_args = esbuild_args
            if args.esbuild_metafile then
              local metafile_output = package_output_target(package, "-metafile.json")
              append_output(metafile_output)
              command_args = command_args .. " --metafile=" .. tostring(shell_quote(metafile_output))
            end
            local bundle_target = append_output(package_output_target(package))
            if has_css then
              append_output(package_output_target(package, ".css"))
            end
            if args.sourcemap then
              append_output(tostring(bundle_target) .. ".map")
              if has_css then
                append_output(package_output_target(package, ".css.map"))
              end
            end
            print(tostring(bundle_target) .. ": " .. tostring(package_source_target(package)))
            print("", "NODE_PATH=" .. tostring(shell_quote(args.source_dir)) .. " $(ESBUILD) " .. tostring(command_args) .. " \"$<\" --outfile=\"$@\"")
            print()
          end
          local _exp_3 = args.minify
          if "both" == _exp_3 or "only" == _exp_3 then
            local command_args = esbuild_args
            if args.esbuild_metafile then
              local metafile_output = package_output_target(package, ".min-metafile.json")
              append_output(metafile_output)
              command_args = command_args .. " --metafile=" .. tostring(shell_quote(metafile_output))
            end
            local bundle_target = append_output(package_output_target(package, ".min.js"))
            if has_css then
              append_output(package_output_target(package, ".min.css"))
            end
            if args.sourcemap then
              append_output(tostring(bundle_target) .. ".map")
              if has_css then
                append_output(package_output_target(package, ".min.css.map"))
              end
            end
            print(tostring(bundle_target) .. ": " .. tostring(package_source_target(package)))
            print("", "NODE_PATH=" .. tostring(shell_quote(args.source_dir)) .. " $(ESBUILD) " .. tostring(command_args) .. " --minify \"$<\" --outfile=\"$@\"")
            print()
          end
        end
      end
      print("# Misc rules")
      print("clean:")
      if next(all_outputs) then
        return print("", "rm " .. tostring(table.concat((function()
          local _accum_0 = { }
          local _len_0 = 1
          for _index_0 = 1, #all_outputs do
            local o = all_outputs[_index_0]
            _accum_0[_len_0] = shell_quote(o)
            _len_0 = _len_0 + 1
          end
          return _accum_0
        end)(), " ")))
      end
    end
  elseif "debug" == _exp_0 then
    local Widget = require(args.module_name)
    assert(subclass_of(require("lapis.eswidget"))(Widget), "You attempted to load a module that doesn't extend `lapis.eswidget`")
    print("Config")
    print("==================")
    print("widget name", Widget:widget_name())
    print("packages:", table.concat(Widget.asset_packages, ", "))
    print("init method:", Widget:es_module_init_function_name())
    print("class names:", table.concat({
      Widget:widget_class_list()
    }, ", "))
    print()
    print("CSS")
    print("==================")
    if rawget(Widget, "css_module") then
      print("css_module:", "(inline CSS defined)")
    elseif rawget(Widget, "css_file") then
      print("css_file:", Widget.css_file)
    else
      print("(no CSS defined)")
    end
    local css_deps = Widget.css_module_dependencies
    if css_deps and next(css_deps) then
      print("css dependencies:", table.concat(css_deps, ", "))
    end
    print()
    print()
    print("Dependencies")
    print("==================")
    local deps = Widget.es_module_dependencies
    if deps and next(deps) then
      if args.recursive then
        local visited = { }
        local print_dep_tree
        print_dep_tree = function(dep, indent, is_last)
          if indent == nil then
            indent = ""
          end
          if is_last == nil then
            is_last = true
          end
          local connector
          if indent == "" then
            connector = ""
          elseif is_last then
            connector = "└ "
          else
            connector = "├ "
          end
          print(tostring(indent) .. tostring(connector) .. tostring(dep))
          if visited[dep] then
            return 
          end
          visited[dep] = true
          local ok, mod = pcall(require, dep)
          if not (ok and type(mod) == "table") then
            local branch_indent
            if is_last then
              branch_indent = "    "
            else
              branch_indent = "│   "
            end
            print(tostring(indent) .. tostring(branch_indent) .. "(failed to load: " .. tostring(mod) .. ")")
            return 
          end
          local subdeps = mod.es_module_dependencies
          if not (subdeps and next(subdeps)) then
            return 
          end
          local next_indent = indent .. ((function()
            if is_last then
              return "  "
            else
              return "│ "
            end
          end)())
          for i, subdep in ipairs(subdeps) do
            print_dep_tree(subdep, next_indent, i == #subdeps)
          end
        end
        for i, dep in ipairs(deps) do
          print_dep_tree(dep, "", i == #deps)
        end
      else
        for _index_0 = 1, #deps do
          local dep = deps[_index_0]
          print(dep)
        end
      end
    else
      print("(none)")
    end
    print()
    print("ES module")
    print("==================")
    return print(Widget:compile_es_module())
  else
    return error("unhandled command: " .. tostring(args.command))
  end
end
return _M
