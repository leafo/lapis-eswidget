
import sorted_pairs from require "spec.helpers"
-- NOTE: only require lapis modules within tests or before, as sorted_pairs
-- will reset the scope for clean slate every test

import types from require "tableshape"

describe "eswidget.cmd", ->
  local snapshot

  local print_buffer

  get_output = ->
    table.concat [line .. "\n" for line in *print_buffer]

  before_each ->
    snapshot = assert\snapshot!
    print_buffer = {}

    stub require("lapis.eswidget.cmd"), "print", (...) ->
      table.insert print_buffer, table.concat {...}, "\t"

  after_each ->
    snapshot\revert!

  describe "compile_js", ->
    it "compiles by filename", ->
      import trim from require "lapis.util"
      import run from require "lapis.eswidget.cmd"

      run {
        command: "compile_js"
        moonscript: true
        file: "spec/views/login.moon"
      }

      assert.same [[window.init_Login = function(widget_selector, widget_params) {
    console.log("Login!", widget_selector, widget_params)
}]], trim get_output!

    it "compiles module", ->
      import trim from require "lapis.util"
      import run from require "lapis.eswidget.cmd"

      run {
        command: "compile_js"
        moonscript: true
        module: "spec.views.user_profile"
      }

      assert.same [[window.init_UserProfile = function(widget_selector, widget_params) {
    console.log("User profile!", widget_selector, widget_params)
}]], trim get_output!

    it "compiles entire package", ->
      import trim from require "lapis.util"
      import run from require "lapis.eswidget.cmd"

      run {
        command: "compile_js"
        moonscript: true
        package: "main"
        widget_dirs: {"spec/views"}
      }

      assert.same [[// spec/views/login.moon (main)
window.init_Login = function(widget_selector, widget_params) {
    console.log("Login!", widget_selector, widget_params)
}

// spec/views/user_profile.moon (main)
window.init_UserProfile = function(widget_selector, widget_params) {
    console.log("User profile!", widget_selector, widget_params)
}]], trim get_output!

    it "fails for empty/invalid package", ->
      import run from require "lapis.eswidget.cmd"

      assert.has_error(
        ->
          run {
            command: "compile_js"
            moonscript: true
            package: "fart"
            widget_dirs: {"spec/views"}
          }

        "You attempted to compile a package that has no matching widgets, aborting (package: fart)"
      )

    it "fails on non-eswidget module", ->
      import run from require "lapis.eswidget.cmd"

      assert.has_error(
        ->
          run {
            command: "compile_js"
            moonscript: true
            file: "spec/views/other_thing.moon"
          }
        "You attempted to compile a module that doesn't extend `lapis.eswidget`. Only ESWidget is supported for compiling to JavaScript"
      )

    it "empty call erorr", ->
      import run from require "lapis.eswidget.cmd"

      assert.has_error(
        ->
          run {
            command: "compile_js"
            moonscript: true
          }
        "You called compile_js but did not specify what to compile. Provide one of: --file, --module, or --package"
      )

  describe "generate_spec", ->
    it "generates simple tupfile", ->
      import run from require "lapis.eswidget.cmd"
      run {
        command: "generate_spec"
        format: "tup"
        moonscript: true
        widget_dirs: {"spec/views"}
        source_dir: "spec/static/js"
        output_dir: "spec/static"
      }

      assert.same [[# This file is automatically generated, do not edit
export LUA_PATH
export LUA_CPATH

!compile_js = |> ^ compile_js %f > %o^ lapis-eswidget compile_js --moonscript --file %f > %o |>
!join_bundle = |> ^ join bundle %o^ (for file in %f; do echo 'import "../../../'$file'";' | sed 's/\.js//'; done) > %o |>
!esbuild_bundle = |> ^ esbuild bundle %o^ NODE_PATH=spec/static/js $(ESBUILD) --target=es6 --log-level=warning --bundle %f --outfile=%o |>
!esbuild_bundle_minified = |> ^ esbuild minified bundle %o^ NODE_PATH=spec/static/js $(ESBUILD) --target=es6 --log-level=warning --minify --bundle %f --outfile=%o |>


# package: main
: spec/views/login.moon |> !compile_js |> spec/views/login.js {package_main}
: spec/views/user_profile.moon |> !compile_js |> spec/views/user_profile.js {package_main}
: {package_main} |> !join_bundle |> spec/static/js/main.js
: spec/static/js/main.js | {package_main} |> !esbuild_bundle |> spec/static/main.js {packages}

# minifying packages
: spec/static/js/main.js | {packages} |> !esbuild_bundle_minified |> spec/static/main.min.js
]], get_output!

    it "generates customized tupfile", ->
      import run from require "lapis.eswidget.cmd"
      run {
        command: "generate_spec"
        format: "tup"
        moonscript: true
        widget_dirs: {"spec/views"}
        source_dir: "spec/static/js"
        output_dir: "spec/static"
        esbuild_bin: "ezbuild"
        tup_compile_dep_group: "$(TOP)/<moon>"
        tup_bundle_dep_group: "$(TOP)/<coffee>"
      }

      assert.same [[# This file is automatically generated, do not edit
export LUA_PATH
export LUA_CPATH
ESBUILD=ezbuild

!compile_js = |> ^ compile_js %f > %o^ lapis-eswidget compile_js --moonscript --file %f > %o |>
!join_bundle = |> ^ join bundle %o^ (for file in %f; do echo 'import "../../../'$file'";' | sed 's/\.js//'; done) > %o |>
!esbuild_bundle = |> ^ esbuild bundle %o^ NODE_PATH=spec/static/js $(ESBUILD) --target=es6 --log-level=warning --bundle %f --outfile=%o |>
!esbuild_bundle_minified = |> ^ esbuild minified bundle %o^ NODE_PATH=spec/static/js $(ESBUILD) --target=es6 --log-level=warning --minify --bundle %f --outfile=%o |>


# package: main
: spec/views/login.moon | $(TOP)/<moon> |> !compile_js |> spec/views/login.js {package_main}
: spec/views/user_profile.moon | $(TOP)/<moon> |> !compile_js |> spec/views/user_profile.js {package_main}
: {package_main} |> !join_bundle |> spec/static/js/main.js
: spec/static/js/main.js | {package_main} $(TOP)/<coffee> |> !esbuild_bundle |> spec/static/main.js {packages}

# minifying packages
: spec/static/js/main.js | {packages} |> !esbuild_bundle_minified |> spec/static/main.min.js
]], get_output!

    it "generates json", ->
      import run from require "lapis.eswidget.cmd"
      run {
        command: "generate_spec"
        format: "json"
        moonscript: true
        widget_dirs: {"spec/views"}
        source_dir: "spec/static/js"
        output_dir: "spec/static"
      }

      import from_json from require "lapis.util"

      assert_result = types.assert types.shape {
        config: types.shape {
          moonscript: true
          source_dir: "spec/static/js"
          output_dir: "spec/static"
        }
        packages: types.shape {
          main: types.table
        }
        widgets: types.table
      }

      assert_result from_json get_output!

    it "generates simple makefile", ->
      import trim from require "lapis.util"
      import run from require "lapis.eswidget.cmd"
      run {
        command: "generate_spec"
        format: "makefile"
        moonscript: true
        widget_dirs: {"spec/views"}
        source_dir: "spec/static/js"
        output_dir: "spec/static"
      }

      assert.same [[ESBUILD=esbuild

.PHONY: all clean
all: spec/static/main.js spec/static/main.min.js

# Building modules
spec/views/login.js: spec/views/login.moon
	lapis-eswidget compile_js --moonscript --file "$<" > "$@"

spec/views/user_profile.js: spec/views/user_profile.moon
	lapis-eswidget compile_js --moonscript --file "$<" > "$@"

# Building packages
spec/static/js/main.js: spec/views/login.js spec/views/user_profile.js
	mkdir -p "spec/static/js"
	(for file in $^; do echo 'import "../../../'$$file'";' | sed 's/\.js//'; done) > "$@"

spec/static/main.js: spec/static/js/main.js
	mkdir -p "spec/static"
	NODE_PATH=spec/static/js $(ESBUILD) --target=es6 --log-level=warning --bundle $< --outfile=$@

spec/static/main.min.js: spec/static/js/main.js
	mkdir -p "spec/static"
	NODE_PATH=spec/static/js $(ESBUILD) --target=es6 --log-level=warning --minify --bundle $< --outfile=$@

# Misc rules
clean:
	rm spec/views/login.js spec/views/user_profile.js spec/static/js/main.js spec/static/main.js spec/static/main.min.js]], trim get_output!

describe "eswidget", ->
  sorted_pairs!

  local snapshot

  -- make random return incremening integers
  before_each ->
    snapshot = assert\snapshot!
    k = 0
    stub math, "random", ->
      k += 1
      k

  after_each ->
    snapshot\revert!

  describe "widget_class_list", ->
    it "generates nothing for base class", ->
      Widget = require "lapis.eswidget"
      assert.same {}, {Widget\widget_class_list!}

    it "generates class list", ->
      class UserProfile extends require "lapis.eswidget"
      class CustomUserProfile extends UserProfile
      assert.same {"user_profile_widget"}, {UserProfile\widget_class_list!}
      assert.same {"custom_user_profile_widget", "user_profile_widget"}, {CustomUserProfile\widget_class_list!}

    it "generates class list without including mixins classes", ->
      class MixinA
        hello: => "world"

      class MixinB
        another: => "zone"

      class UserProfile extends require "lapis.eswidget"
        @include MixinA

      class CustomUserProfile extends UserProfile
        @include MixinB

      assert.same {"custom_user_profile_widget", "user_profile_widget"}, {CustomUserProfile\widget_class_list!}

    it "generates class list with custom suffix", ->
      class BasePage extends require "lapis.eswidget"
        @widget_class_name: =>
          if @ == BasePage
            "page"
          else
            "#{@widget_name!}_page"

      class HelloWorld extends BasePage
      class LogIn extends HelloWorld

      assert.same {"page"}, {BasePage\widget_class_list!}
      assert.same {"hello_world_page", "page"}, {HelloWorld\widget_class_list!}
      assert.same {"log_in_page", "hello_world_page", "page"}, {LogIn\widget_class_list!}

  describe "content", ->
    it "renders empty widget", ->
      class UserProfile extends require "lapis.eswidget"
      class CustomUserProfile extends UserProfile

      assert.same [[<div class="user_profile_widget" id="user_profile_1"></div>]], UserProfile!\render_to_string!

      assert.same [[<div class="custom_user_profile_widget user_profile_widget" id="custom_user_profile_2"></div>]], CustomUserProfile!\render_to_string!

    it "renders widget with code es_module", ->
      class UserProfile extends require "lapis.eswidget"
        @es_module: [[
          console.log(widget_selector, widget_params)
        ]]

      assert.same [[<div class="user_profile_widget" id="user_profile_1"></div><script type="text/javascript">init_UserProfile('#user_profile_1', null);</script>]], UserProfile!\render_to_string!


    it "renders js_init into content_for buffer", ->
      class InnerThing extends require "lapis.eswidget"
        @es_module: [[console.log('another thing..')]]

        js_init: =>
          super { items: {1,2,3} }

      class UserProfile extends require "lapis.eswidget"
        @es_module: [[
          console.log(widget_selector, widget_params)
        ]]

        inner_content: =>
          widget InnerThing!

      layout_opts = {}

      widget = UserProfile!
      widget\include_helper { :layout_opts }
      assert.same [[<div class="user_profile_widget" id="user_profile_1"><div class="inner_thing_widget" id="inner_thing_2"></div></div>]], widget\render_to_string!
      assert.same {
        _content_for_js_init: {
          [[init_UserProfile('#user_profile_1', null);]]
          [[init_InnerThing('#inner_thing_2', {"items":[1,2,3]});]]
        }
      }, layout_opts


  describe "js_init", ->
    it "no default js_init if module is not specified", ->
      class MyWidget extends require "lapis.eswidget"
      widget = MyWidget!
      assert.same {nil, "widget does not have an @@es_module"}, {widget\js_init!}

    it "generates default js_init", ->
      class MyWidget extends require "lapis.eswidget"
        @es_module: [[alert('hello world')]]

      widget = MyWidget!
      widget2 = MyWidget!

      assert.same {"init_MyWidget('#my_widget_1', null);"}, {widget\js_init!}
      -- returns same initialization
      assert.same {"init_MyWidget('#my_widget_1', null);"}, {widget\js_init!}

      -- returns different id to avoid conflict
      assert.same {"init_MyWidget('#my_widget_2', null);"}, {widget2\js_init!}

    it "js_init with parameters", ->
      class MyWidget extends require "lapis.eswidget"
        @es_module: [[alert('hello world')]]

        js_init: =>
          super {
            color: "blue"
          }

      widget = MyWidget!
      assert.same {[[init_MyWidget('#my_widget_1', {"color":"blue"});]]}, {widget\js_init!}

  describe "compile_es_module", ->
    it "attempts to compile module without code", ->
      class MyWidget extends require "lapis.eswidget"

      assert.same {nil, "no @@es_module"}, {
        MyWidget\compile_es_module!
      }

    it "compiles simple module", ->
      class MyWidget extends require "lapis.eswidget"
        @es_module: [[
          import Thing from "code/my_things"
          new Thing(widget_selector, widget_params)
        ]]

      output = assert MyWidget\compile_es_module!
      assert.same [[import Thing from "code/my_things"
window.init_MyWidget = function(widget_selector, widget_params) {
          new Thing(widget_selector, widget_params)
}]], output

    it "compiles with custom function name", ->
      class MyWidget extends require "lapis.eswidget"
        @es_module_init_function_name: => "get_started"
        @es_module: [[
          import First from "first"
          alert('hi there')
          import Second from "second"
        ]]

      output = assert MyWidget\compile_es_module!
      assert.same [[import First from "first"
import Second from "second"
window.get_started = function(widget_selector, widget_params) {
          alert('hi there')
}]], output

  describe "prop_types", ->
    import types from require "tableshape"

    it "validates simple props", ->
      class Something extends require "lapis.eswidget"
        @prop_types: {
          id: types.number / (n) -> n + 1
          name: types.string
        }

      assert.has_error(
        -> Something {}
        [[Something: field "id": expected type "number", got "nil"; field "name": expected type "string", got "nil"]]
      )

      w = Something { name: "hello", id: 2323 }
      assert.same {
        name: "hello"
        id: 2324
      }, w.props


    it "validates props with type object", ->
      class Something extends require "lapis.eswidget"
        @prop_types: types.partial {
          name: types.string
        }

      assert.has_error(
        -> Something {}
        [[field "name": expected type "string", got "nil"]]
      )

      w = Something { name: "hello", id: 2323, thing: true }
      assert.same {
        name: "hello"
        thing: true
        id: 2323
      }, w.props

