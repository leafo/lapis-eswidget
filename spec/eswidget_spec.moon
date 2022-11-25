
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





