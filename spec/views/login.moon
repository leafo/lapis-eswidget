
class Login extends require "lapis.eswidget"
  @asset_packages: {"main"}

  @es_module: [[
    import "./login.css"
    console.log("Login!", widget_selector, widget_params)
  ]]
