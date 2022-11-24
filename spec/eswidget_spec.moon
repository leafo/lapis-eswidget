

describe "eswidget", ->
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





