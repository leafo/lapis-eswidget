
import sorted_pairs from require "spec.helpers"

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

