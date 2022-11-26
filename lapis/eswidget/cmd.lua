local types
types = require("tableshape").types
local subclass_of
subclass_of = require("tableshape.moonscript").subclass_of
local run
run = function(args)
  local search_extension = "lua"
  if args.moonscript then
    search_extension = "moon"
    require("moonscript")
  end
  local path_to_module
  path_to_module = function(path)
    return (path:gsub("%." .. tostring(search_extension) .. "$", ""):gsub("/+", "."))
  end
  local each_moon_file
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
    each_moon_file = function(...)
      local prefixes = {
        ...
      }
      return coroutine.wrap(function()
        return scan_prefix(unpack(prefixes))
      end)
    end
  end
  local print_warning
  print_warning = function(msg)
    io.stderr:write(msg)
    return io.stderr:write("\n")
  end
  local each_widget
  each_widget = function()
    return coroutine.wrap(function()
      local is_widget = subclass_of(require("lapis.eswidget"))
      for file in each_moon_file(unpack(args.widget_dirs)) do
        local _continue_0 = false
        repeat
          local module_name = path_to_module(file)
          local widget = require(module_name)
          if not (is_widget(widget)) then
            _continue_0 = true
            break
          end
          if not (widget.asset_packages) then
            print_warning("Widget without @asset_packages")
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
    if args.file then
      local widget = require(path_to_module(args.file))
      return print(widget:compile_js_init())
    elseif args.module then
      local widget = require(args.module)
      return print(widget:compile_js_init())
    else
      local count = 0
      for _des_0 in each_widget() do
        local _continue_0 = false
        repeat
          local file, widget
          file, widget = _des_0.file, _des_0.widget
          if args.package then
            if not (types.array_contains(args.package)(widget.asset_packages)) then
              _continue_0 = true
              break
            end
          end
          local js_code = assert(widget:compile_js_init())
          count = count + 1
          print("// " .. tostring(file) .. " (" .. tostring(table.concat(widget.asset_packages, ", ")) .. ")")
          print(js_code)
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      if count == 0 then
        return error("No package files (package: " .. tostring(args.package) .. ")")
      end
    end
  elseif "generate_spec" == _exp_0 then
    local to_json
    to_json = require("lapis.util").to_json
    local _exp_1 = args.format
    if "json" == _exp_1 then
      local asset_spec = { }
      for _des_0 in each_widget() do
        local module_name, widget
        module_name, widget = _des_0.module_name, _des_0.widget
        if next(widget.asset_packages) then
          local _list_0 = widget.asset_packages
          for _index_0 = 1, #_list_0 do
            local package = _list_0[_index_0]
            local _update_0 = package
            asset_spec[_update_0] = asset_spec[_update_0] or { }
            table.insert(asset_spec[package], module_name)
          end
        else
          asset_spec._unassigned = asset_spec._unassigned or { }
          table.insert(asset_spec._unassigned, module_name)
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
      print()
      print("!compile_js = |> ^ compile_js %f > %o^ $(LUAJIT) cmd/widget_helper.lua compile_js --file %f > %o |>")
      print([[!join_bundle = |> ^ join bundle %o^ (for file in %f; do echo 'import "../../'$file'"; ' | sed 's/\.js//'; done) > %o |>]])
      print("!esbuild_bundle = |> ^ esbuild bundle %o^ NODE_PATH=static/coffee $(ESBUILD) --target=es6 --log-level=warning --bundle %f --outfile=%o |>")
      print("!esbuild_bundle_minified = |> ^ esbuild minified bundle %o^ NODE_PATH=static/coffee $(ESBUILD) --target=es6 --log-level=warning --minify --bundle %f --outfile=%o |>")
      print()
      for _index_0 = 1, #packages do
        local package = packages[_index_0]
        local files = package_files[package]
        table.sort(files)
        print()
        print("# package: " .. tostring(package))
        for _index_1 = 1, #files do
          local file = files[_index_1]
          local out_file = file:gsub("%.moon", ".js")
          print(": " .. tostring(file) .. " | $(TOP)/<moon> |> !compile_js |> " .. tostring(out_file) .. " {package_" .. tostring(package) .. "}")
        end
        print(": {package_" .. tostring(package) .. "} |> !join_bundle |> static/coffee/" .. tostring(package) .. ".js")
        print(": static/coffee/" .. tostring(package) .. ".js | {package_" .. tostring(package) .. "} $(TOP)/<coffee> |> !esbuild_bundle |> static/" .. tostring(package) .. ".js {packages}")
      end
      print()
      print("# minifying packages")
      for _index_0 = 1, #packages do
        local package = packages[_index_0]
        print(": static/coffee/" .. tostring(package) .. ".js | {packages} |> !esbuild_bundle_minified |> static/" .. tostring(package) .. ".min.js")
      end
    end
  elseif "debug" == _exp_0 then
    require("moon").p(args)
    local Widget = require(args.module_name)
    print("Config")
    print("==================")
    print("packages:", table.concat(Widget.asset_packages, ", "))
    print("init method:", Widget:js_init_method_name())
    print()
    print("Asset files")
    print("==================")
    print("scss:", Widget:get_asset_file("scss"))
    print("coffee:", Widget:get_asset_file("coffee"))
    print()
    print("JS Init")
    print("==================")
    return print(Widget:compile_js_init())
  end
end
return {
  run = run
}
