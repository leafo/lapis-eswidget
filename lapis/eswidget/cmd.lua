local types
types = require("tableshape").types
local subclass_of
subclass_of = require("tableshape.moonscript").subclass_of
local shell_escape, join
do
  local _obj_0 = require("lapis.cmd.path")
  shell_escape, join = _obj_0.shell_escape, _obj_0.join
end
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
  local each_widget
  each_widget = function()
    return coroutine.wrap(function()
      local is_widget = subclass_of(require("lapis.eswidget"))
      for file in each_module_file(unpack(args.widget_dirs)) do
        local _continue_0 = false
        repeat
          local module_name = path_to_module(file)
          local widget = require(module_name)
          if not (is_widget(widget)) then
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
  local _exp_0 = args.command
  if "compile_js" == _exp_0 then
    local is_widget = subclass_of(require("lapis.eswidget"))
    local invalid_module_error = "You attempted to compile a module that doesn't extend `lapis.eswidget`. Only ESWidget is supported for compiling to JavaScript"
    if args.file then
      local widget = require(path_to_module(args.file))
      assert(is_widget(widget), invalid_module_error)
      return print(widget:compile_es_module())
    elseif args.module then
      local widget = require(args.module)
      assert(is_widget(widget), invalid_module_error)
      return print(widget:compile_es_module())
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
          local js_code = assert(widget:compile_es_module())
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
  elseif "generate_spec" == _exp_0 then
    local to_json
    to_json = require("lapis.util").to_json
    local input_to_output
    input_to_output = function(input_fname)
      return input_fname:gsub("%." .. tostring(search_extension) .. "$", "") .. ".js"
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
    local source_to_top
    do
      if args.source_dir:match("^/") then
        error("--source-dir must be a relative path from the top level directory, and not an absolute path")
      end
      if args.source_dir:match("%.%.") or args.source_dir:match("%./") then
        error("--source-dir must not use ../ or ./")
      end
      source_to_top = args.source_dir:gsub("[^/]+", "..")
    end
    local _exp_1 = args.format
    if "json" == _exp_1 then
      local asset_spec = { }
      for _des_0 in each_widget() do
        local module_name, widget, file
        module_name, widget, file = _des_0.module_name, _des_0.widget, _des_0.file
        asset_spec.widgets = asset_spec.widgets or { }
        asset_spec.widgets[module_name] = {
          path = file,
          name = widget:widget_name(),
          packages = widget.asset_packages,
          class_list = {
            widget:widget_class_list()
          }
        }
        if next(widget.asset_packages) then
          local _list_0 = widget.asset_packages
          for _index_0 = 1, #_list_0 do
            local package = _list_0[_index_0]
            asset_spec.packages = asset_spec.packages or { }
            local _update_0 = package
            asset_spec.packages[_update_0] = asset_spec.packages[_update_0] or { }
            table.insert(asset_spec.packages[package], module_name)
          end
        end
      end
      return print(to_json(asset_spec))
    elseif "tup" == _exp_1 then
      local package_files = { }
      for _des_0 in each_widget() do
        local file, module_name, widget
        file, module_name, widget = _des_0.file, _des_0.module_name, _des_0.widget
        local _list_0 = widget.asset_packages
        for _index_0 = 1, #_list_0 do
          local package = _list_0[_index_0]
          local _update_0 = package
          package_files[_update_0] = package_files[_update_0] or { }
          table.insert(package_files[package], file)
        end
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
      print("# This file is automatically generated, do not edit")
      print("export LUA_PATH")
      print("export LUA_CPATH")
      if args.esbuild_bin then
        print("ESBUILD=" .. tostring(shell_quote(args.esbuild_bin)))
      end
      print()
      print("!compile_js = |> ^ compile_js %f > %o^ lapis-eswidget compile_js " .. tostring(args.moonscript and "--moonscript" or "") .. " --file %f > %o |>")
      print([[!join_bundle = |> ^ join bundle %o^ (for file in %f; do echo 'import "]] .. join(source_to_top, "'$file'") .. [[";' | sed 's/\.js//'; done) > %o |>]])
      print("!esbuild_bundle = |> ^ esbuild bundle %o^ NODE_PATH=" .. tostring(shell_quote(args.source_dir)) .. " $(ESBUILD) --target=es6 --log-level=warning --bundle %f --outfile=%o |>")
      print("!esbuild_bundle_minified = |> ^ esbuild minified bundle %o^ NODE_PATH=" .. tostring(shell_quote(args.source_dir)) .. " $(ESBUILD) --target=es6 --log-level=warning --minify --bundle %f --outfile=%o |>")
      print()
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
      for _index_0 = 1, #packages do
        local package = packages[_index_0]
        local files = package_files[package]
        table.sort(files)
        print()
        print("# package: " .. tostring(package))
        for _index_1 = 1, #files do
          local file = files[_index_1]
          local out_file = input_to_output(file)
          print(": " .. tostring(file) .. tostring(appended_group(args.tup_compile_dep_group, " | ")) .. " |> !compile_js |> " .. tostring(out_file) .. " {package_" .. tostring(package) .. "}")
        end
        print(": {package_" .. tostring(package) .. "} |> !join_bundle |> " .. tostring(shell_quote(package_source_target(package))))
        print(": " .. tostring(package_source_target(package)) .. " | {package_" .. tostring(package) .. "}" .. tostring(appended_group(args.tup_bundle_dep_group, " ")) .. " |> !esbuild_bundle |> " .. tostring(shell_quote(package_output_target(package))) .. " {packages}")
      end
      print()
      print("# minifying packages")
      for _index_0 = 1, #packages do
        local package = packages[_index_0]
        print(": " .. tostring(package_source_target(package)) .. " | {packages} |> !esbuild_bundle_minified |> " .. tostring(shell_quote(package_output_target(package, ".min.js"))))
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
      local final_outputs = { }
      for package in pairs(package_files) do
        table.insert(final_outputs, package_output_target(package))
        table.insert(final_outputs, package_output_target(package, ".min.js"))
      end
      table.sort(final_outputs)
      print("all:: " .. tostring(table.concat(final_outputs, " ")))
      print()
      for _index_0 = 1, #found_widgets do
        local _des_0 = found_widgets[_index_0]
        local file, module_name, widget
        file, module_name, widget = _des_0.file, _des_0.module_name, _des_0.widget
        print(tostring(input_to_output(file)) .. ": " .. tostring(file))
        print("", "lapis-eswidget compile_js " .. tostring(args.moonscript and "--moonscript" or "") .. " --file \"$<\" > \"$@\"")
        print()
      end
      print("# Building Packages")
      for package, files in pairs(package_files) do
        local package_dependencies
        do
          local _accum_0 = { }
          local _len_0 = 1
          for _index_0 = 1, #files do
            local file = files[_index_0]
            _accum_0[_len_0] = input_to_output(file)
            _len_0 = _len_0 + 1
          end
          package_dependencies = _accum_0
        end
        print(tostring(package_source_target(package)) .. ": " .. tostring(table.concat(package_dependencies, " ")))
        print("", "mkdir -p \"" .. tostring(args.source_dir) .. "\"")
        print("", [[(for file in $^; do echo 'import "]] .. join(source_to_top, "'$$file'") .. [[";' | sed 's/\.js//'; done) > "$@"]])
        print()
        print(tostring(package_output_target(package)) .. ": " .. tostring(package_source_target(package)))
        print("", "mkdir -p \"" .. tostring(args.output_dir) .. "\"")
        print("", "NODE_PATH=" .. tostring(shell_quote(args.source_dir)) .. " $(ESBUILD) --target=es6 --log-level=warning --bundle $< --outfile=$@")
        print()
        print(tostring(package_output_target(package, ".min.js")) .. ": " .. tostring(package_source_target(package)))
        print("", "mkdir -p \"" .. tostring(args.output_dir) .. "\"")
        print("", "NODE_PATH=" .. tostring(shell_quote(args.source_dir)) .. " $(ESBUILD) --target=es6 --log-level=warning --minify --bundle $< --outfile=$@")
        print()
      end
    end
  elseif "debug" == _exp_0 then
    local Widget = require(args.module_name)
    print("Config")
    print("==================")
    print("widget name", Widget:widget_name())
    print("packages:", table.concat(Widget.asset_packages, ", "))
    print("init method:", Widget:es_module_init_function_name())
    print("class names:", table.concat({
      Widget:widget_class_list()
    }, ", "))
    print()
    print()
    print("ES module")
    print("==================")
    return print(Widget:compile_es_module())
  else
    return error("unhandled command: " .. tostring(args.command))
  end
end
return _M
