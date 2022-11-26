
class Login extends require "lapis.eswidget"
  @asset_packages: {"main"}

  @es_module: [[
    console.log("Login!", widget_selector, widget_params)
  ]]
