
import sorted_pairs from require "spec.helpers"
-- NOTE: only require lapis modules within tests or before, as sorted_pairs
-- will reset the scope for clean slate every test

import types from require "tableshape"

EXPECTED_OUTPUTS = "spec/expected_outputs"

get_expected_output = (name) ->
  f = assert io.open "#{EXPECTED_OUTPUTS}/#{name}", "r"
  f\read "*a"

describe "eswidget.cmd", ->
  local snapshot

  local print_buffer

  get_output = ->
    table.concat [line .. "\n" for line in *print_buffer]

  assert_expected_output = (name) ->
    if os.getenv "REBUILD_EXPECTED_OUTPUT"
      f = assert io.open "#{EXPECTED_OUTPUTS}/#{name}", "w"
      f\write get_output!
      f\close!
      return pending "Rebuilt #{EXPECTED_OUTPUTS}/#{name}, confirm with git-diff before checking in"

    expected = get_expected_output(name)
    assert.same expected, get_output!

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

      assert.same [[import "./login.css"
window.init_Login = function(widget_selector, widget_params) {
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
      import run from require "lapis.eswidget.cmd"

      run {
        command: "compile_js"
        moonscript: true
        package: "main"
        widget_dirs: {"spec/views"}
      }

      assert_expected_output "main_package.js"

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
        minify: "both"
      }

      assert_expected_output "simple_tupfile.tup"

    it "generates tupfile without bundling", ->
      import run from require "lapis.eswidget.cmd"
      run {
        command: "generate_spec"
        format: "tup"
        moonscript: true
        widget_dirs: {"spec/views"}
        source_dir: "spec/static/js"
        output_dir: "spec/static"
        minify: "both"
        skip_bundle: true
      }

      assert_expected_output "skip_bundle_tupfile.tup"

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
        css_packages: {"main"}
        tup_compile_dep_group: "$(TOP)/<moon>"
        tup_bundle_dep_group: "$(TOP)/<coffee>"
        minify: "only"
        metafile: true
        sourcemap: true
      }

      assert_expected_output "customized_tupfile.tup"

    it "generates json", ->
      import run from require "lapis.eswidget.cmd"
      run {
        command: "generate_spec"
        format: "json"
        moonscript: true
        widget_dirs: {"spec/views"}
        source_dir: "spec/static/js"
        output_dir: "spec/static"
        esbuild_args: "--exclude:jquery"
      }

      import from_json from require "lapis.util"

      assert_result = types.assert types.shape {
        config: types.shape {
          moonscript: true
          esbuild_args: "--target=es6 --log-level=warning --bundle --exclude:jquery"
          source_dir: "spec/static/js"
          output_dir: "spec/static"
        }
        packages: types.shape {
          main: types.table
          settings: types.table
        }
        widgets: types.table
      }

      assert_result from_json get_output!

    it "generates simple makefile", ->
      import run from require "lapis.eswidget.cmd"
      run {
        command: "generate_spec"
        format: "makefile"
        moonscript: true
        widget_dirs: {"spec/views"}
        source_dir: "spec/static/js"
        output_dir: "spec/static"
        minify: "none"
      }

      assert_expected_output "simple_makefile"

    it "generates makefile without bundling", ->
      import run from require "lapis.eswidget.cmd"
      run {
        command: "generate_spec"
        format: "makefile"
        moonscript: true
        widget_dirs: {"spec/views"}
        source_dir: "spec/static/js"
        output_dir: "spec/static"
        skip_bundle: true
        minify: "none"
      }

      assert_expected_output "no_bundle_makefile"


    it "generates customized makefile", ->
      import run from require "lapis.eswidget.cmd"
      run {
        command: "generate_spec"
        format: "makefile"
        moonscript: true
        widget_dirs: {"spec/views"}
        source_dir: "spec/static/js"
        output_dir: "spec/static"
        esbuild_bin: "ezbuild"
        minify: "only"
        sourcemap: true
        metafile: true
        css_packages: {"main"}
      }

      assert_expected_output "customized_makefile"

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


    it "renders with overridden content method", ->
      class ItemPage extends require "lapis.eswidget"
        content: =>
          -- this is ugly but currently the only way to do this
          @_buffer\call super.content, @, ->
            div "What the heck?"

      assert.same [[<div class="item_page_widget" id="item_page_1"><div>What the heck?</div></div>]], ItemPage!\render_to_string!

    describe "widget_enclosing_element", ->
      it "overrides default", ->
        class UserProfile extends require "lapis.eswidget"
          widget_enclosing_element: "span"

        class AlertPage extends require "lapis.eswidget"
          widget_enclosing_element: "section"
          widget_enclosing_attributes: =>
            attr = super!
            attr.class = nil
            attr.role = "alert"
            attr

          js_init: => "alert('hi')"

          inner_content: =>
            pre "cool"


        assert.same [[<span class="user_profile_widget" id="user_profile_1"></span>]], UserProfile!\render_to_string!
        assert.same [[<section id="alert_page_2" role="alert"><pre>cool</pre></section><script type="text/javascript">alert('hi')</script>]], AlertPage!\render_to_string!

      it "skips enclosing element", ->
        class UserProfile extends require "lapis.eswidget"
          widget_enclosing_element: false

        class AlertPage extends require "lapis.eswidget"
          widget_enclosing_element: false

          js_init: => "alert('hi')"

          inner_content: =>
            pre "cool"

        assert.same [[]], UserProfile!\render_to_string!
        assert.same [[<pre>cool</pre><script type="text/javascript">alert('hi')</script>]], AlertPage!\render_to_string!

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
          [[init_InnerThing('#inner_thing_2', {"items":[1,2,3]});]]
          [[init_UserProfile('#user_profile_1', null);]]
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
      class SimpleProps extends require "lapis.eswidget"
        @prop_types: {
          id: types.number / (n) -> n + 1
          name: types.string
        }

      assert.has_error(
        -> SimpleProps {}
        [[SimpleProps: field "id": expected type "number", got "nil"; field "name": expected type "string", got "nil"]]
      )

      w = SimpleProps { name: "hello", id: 2323 }
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

    it "validates from render props", ->
      import render_prop, RENDER_PROPS_KEY from require "lapis.eswidget.prop_types"

      -- NOTE: we do it this way because in Lua5.1 the function locker can not
      -- bind the closure, and it has a copy of the closure
      did_render = {}

      class HasRenderProps extends require "lapis.eswidget"
        -- NOTE: Do not add any transformsations to this spec, we want to test
        -- passing through object to ensure all props make are copied over ,
        -- and aren't in the metatable.
        @prop_types: {
          name: render_prop types.string
          id: types.number
        }

        content: =>
          did_render.rendered = true

          assert.nil getmetatable(@props), "@props should NOT have a metatable"

          assert.same {
            id: 55
            name: "cool"
          }, @props

          div "hello world"


      do
        did_render.rendered = false
        widget = HasRenderProps { id: 55 }

        -- render props should be created
        assert.truthy widget[RENDER_PROPS_KEY]

        -- include a helper that provides the render prop
        widget\include_helper {
          name: "cool"
        }

        widget\render_to_string!
        assert.same {rendered: true}, did_render, "widget should have rendered"

        -- ensure that props was restored
        assert.same {id: 55}, widget.props

      do
        did_render.rendered = false
        widget = HasRenderProps { id: 55, name: "cool" }
        initial_props = widget.props

        -- render props should not be created
        assert.nil widget[RENDER_PROPS_KEY]

        -- include a helper that provides the render prop, but it would be ignored
        widget\include_helper {
          name: "sir"
        }

        widget\render_to_string!
        assert.same {rendered: true}, did_render, "widget should have rendered"

        -- ensure that props aren't changed
        assert.same {id: 55, name: "cool"}, widget.props
        assert widget.props == initial_props


    it "handles error for missing props", ->
      import render_prop, RENDER_PROPS_KEY from require "lapis.eswidget.prop_types"

      class HasRenderProps extends require "lapis.eswidget"
        @prop_types: {
          name: render_prop types.string / "WHOA"
          id: types.number
        }

        content: =>
          span "okay"

      assert.has_error(
        -> HasRenderProps { }
        [[HasRenderProps: field "id": expected type "number", got "nil"]]
      )

      do -- render with no helper
        widget = HasRenderProps { id: 54 }
        assert.has_error(
          -> widget\render_to_string!
          [[HasRenderProps: field "name": expected type "string", got "nil"]]
        )

      do -- render with no helpers that satisfiy requirement
        widget = HasRenderProps { id: 54 }
        widget\include_helper { job: false }
        assert.has_error(
          -> widget\render_to_string!
          [[HasRenderProps: field "name": expected type "string", got "nil"]]
        )

      do -- render with helper that has wrong type
        widget = HasRenderProps { id: 54 }
        widget\include_helper { job: false }
        widget\include_helper { name: true }

        assert.has_error(
          -> widget\render_to_string!
          [[HasRenderProps: field "name": expected type "string", got "boolean"]]
        )

      do -- use constructor value as precedence
        widget = HasRenderProps { id: 54, name: "hello" }
        assert.same nil, widget[RENDER_PROPS_KEY] -- no render props assigned, satisfied via constructor
        widget\render_to_string! -- no error

        assert.same {
          id: 54
          name: "WHOA"
        }, widget.props


