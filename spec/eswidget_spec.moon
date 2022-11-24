

describe "eswidget", ->
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





